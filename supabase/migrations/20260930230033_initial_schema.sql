-- Esquema inicial de mitimiti: grupos, miembros, categorías, gastos y pagos.
-- Montos en centavos de ARS (bigint). Refleja lib/domain/.

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  invite_code text not null unique
    default upper(substr(md5(gen_random_uuid()::text), 1, 6)),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index group_members_user_id_idx on public.group_members (user_id);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  unique (group_id, name),
  -- Permite FK compuesta desde expenses para asegurar mismo grupo.
  unique (id, group_id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  paid_by uuid not null,
  amount_cents bigint not null check (amount_cents > 0),
  category_id uuid not null,
  description text not null default '',
  spent_on date not null default current_date,
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  -- Quien pagó tiene que ser miembro del grupo.
  foreign key (group_id, paid_by)
    references public.group_members (group_id, user_id),
  -- La categoría tiene que ser del mismo grupo.
  foreign key (category_id, group_id)
    references public.categories (id, group_id)
);

create index expenses_group_spent_on_idx
  on public.expenses (group_id, spent_on desc);

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  from_user_id uuid not null,
  to_user_id uuid not null,
  amount_cents bigint not null check (amount_cents > 0),
  settled_on date not null default current_date,
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  check (from_user_id <> to_user_id),
  foreign key (group_id, from_user_id)
    references public.group_members (group_id, user_id),
  foreign key (group_id, to_user_id)
    references public.group_members (group_id, user_id)
);

create index settlements_group_idx on public.settlements (group_id);

-- ---------------------------------------------------------------------------
-- Perfil automático al registrarse
-- ---------------------------------------------------------------------------

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'name', ''),
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Helpers y RPCs
-- ---------------------------------------------------------------------------

-- security definer para evitar recursión en las políticas de group_members.
create function public.is_group_member(gid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = (select auth.uid())
  );
$$;

-- Crea el grupo, agrega al creador como miembro y carga categorías por
-- defecto, todo en una transacción. Es la única forma de crear grupos.
create function public.create_group(group_name text)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.groups;
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;

  insert into public.groups (name, created_by)
  values (group_name, auth.uid())
  returning * into g;

  insert into public.group_members (group_id, user_id)
  values (g.id, auth.uid());

  insert into public.categories (group_id, name)
  select g.id, unnest(array[
    'Supermercado', 'Alquiler y expensas', 'Servicios', 'Limpieza',
    'Comida afuera', 'Hogar', 'Transporte', 'Otros'
  ]);

  return g;
end;
$$;

-- Unirse con el código de invitación. Idempotente si ya es miembro.
create function public.join_group(code text)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.groups;
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;

  select * into g from public.groups
  where invite_code = upper(trim(code));

  if not found then
    raise exception 'Código de invitación inválido';
  end if;

  insert into public.group_members (group_id, user_id)
  values (g.id, auth.uid())
  on conflict do nothing;

  return g;
end;
$$;

revoke execute on function public.is_group_member(uuid) from public, anon;
revoke execute on function public.create_group(text) from public, anon;
revoke execute on function public.join_group(text) from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.create_group(text) to authenticated;
grant execute on function public.join_group(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Permisos de tabla para la Data API (el proyecto no expone tablas nuevas
-- automáticamente). Qué filas se ven lo decide RLS más abajo.
-- ---------------------------------------------------------------------------

grant select, update on public.profiles to authenticated;
grant select, update on public.groups to authenticated;
grant select, delete on public.group_members to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;
grant select, insert, delete on public.settlements to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.categories enable row level security;
alter table public.expenses enable row level security;
alter table public.settlements enable row level security;

-- profiles: el propio y los de quienes comparten algún grupo.
create policy "profiles_select" on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1 from public.group_members m
      where m.user_id = profiles.id and public.is_group_member(m.group_id)
    )
  );

create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- groups: se ven los propios; alta solo vía create_group / join_group.
create policy "groups_select" on public.groups
  for select to authenticated
  using (public.is_group_member(id));

create policy "groups_update" on public.groups
  for update to authenticated
  using (public.is_group_member(id))
  with check (public.is_group_member(id));

-- group_members: se ven los miembros de mis grupos; cada uno puede salir.
create policy "group_members_select" on public.group_members
  for select to authenticated
  using (public.is_group_member(group_id));

create policy "group_members_delete_self" on public.group_members
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- categories, expenses, settlements: todo miembro puede leer y escribir.
create policy "categories_all" on public.categories
  for all to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

create policy "expenses_select" on public.expenses
  for select to authenticated
  using (public.is_group_member(group_id));

create policy "expenses_insert" on public.expenses
  for insert to authenticated
  with check (
    public.is_group_member(group_id) and created_by = (select auth.uid())
  );

create policy "expenses_update" on public.expenses
  for update to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

create policy "expenses_delete" on public.expenses
  for delete to authenticated
  using (public.is_group_member(group_id));

create policy "settlements_select" on public.settlements
  for select to authenticated
  using (public.is_group_member(group_id));

create policy "settlements_insert" on public.settlements
  for insert to authenticated
  with check (
    public.is_group_member(group_id) and created_by = (select auth.uid())
  );

create policy "settlements_delete" on public.settlements
  for delete to authenticated
  using (public.is_group_member(group_id));

-- ---------------------------------------------------------------------------
-- Realtime: que el otro vea los gastos nuevos sin refrescar.
-- ---------------------------------------------------------------------------

alter publication supabase_realtime
  add table public.expenses, public.settlements;
