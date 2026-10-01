-- Qué notificaciones quiere recibir cada usuario. Sin fila = todas activadas.
create table public.notification_prefs (
  user_id uuid primary key default auth.uid()
    references public.profiles (id) on delete cascade,
  -- Alguien cargó un gasto.
  expense_new boolean not null default true,
  -- Alguien editó o borró un gasto.
  expense_changed boolean not null default true,
  -- Alguien registró un pago que te involucra.
  settlement boolean not null default true,
  -- Alguien se unió al grupo.
  member_joined boolean not null default true,
  updated_at timestamptz not null default now()
);

grant select, insert, update on public.notification_prefs to authenticated;
-- La Edge Function `notify` las lee para decidir a quién avisar.
grant select on public.notification_prefs to service_role;

alter table public.notification_prefs enable row level security;

create policy "notification_prefs_own" on public.notification_prefs
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
