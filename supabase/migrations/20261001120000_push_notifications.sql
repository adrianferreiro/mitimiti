-- Notificaciones push: tokens de dispositivo y triggers que avisan a la Edge
-- Function `notify` (supabase/functions/notify) cuando otro miembro carga,
-- edita o borra un gasto, registra un pago o se une al grupo.

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- Tokens de FCM por dispositivo
-- ---------------------------------------------------------------------------

-- Un token es de un dispositivo; si en ese dispositivo entra otra cuenta, el
-- token pasa a ser de esa cuenta.
create table public.device_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

create index device_tokens_user_id_idx on public.device_tokens (user_id);

-- Sin políticas ni grants: la app solo los toca vía las RPCs de abajo y la
-- Edge Function los lee con la service role.
alter table public.device_tokens enable row level security;

create function public.register_device_token(
  device_token text,
  device_platform text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;

  insert into public.device_tokens (token, user_id, platform)
  values (device_token, auth.uid(), device_platform)
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

-- Al cerrar sesión, para que el dispositivo deje de recibir avisos de esa
-- cuenta.
create function public.unregister_device_token(device_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.device_tokens
  where token = device_token and user_id = (select auth.uid());
$$;

revoke execute on function public.register_device_token(text, text)
  from public, anon;
revoke execute on function public.unregister_device_token(text)
  from public, anon;
grant execute on function public.register_device_token(text, text)
  to authenticated;
grant execute on function public.unregister_device_token(text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Triggers → Edge Function
-- ---------------------------------------------------------------------------

-- Manda el cambio a la Edge Function con pg_net (asíncrono: si falla el envío
-- no afecta al gasto/pago). `actor` es quien hizo el cambio, para no avisarle
-- a él mismo. La URL de la función y el secreto compartido están en Vault
-- (`notify_url`, `notify_secret`); si faltan, no se notifica.
create function public.notify_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  fn_url text;
  fn_secret text;
begin
  select decrypted_secret into fn_url
  from vault.decrypted_secrets where name = 'notify_url';
  select decrypted_secret into fn_secret
  from vault.decrypted_secrets where name = 'notify_secret';

  if fn_url is null or fn_secret is null then
    return null;
  end if;

  perform net.http_post(
    url := fn_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-notify-secret', fn_secret
    ),
    body := jsonb_build_object(
      'table', tg_table_name,
      'type', tg_op,
      'record', case when tg_op <> 'DELETE' then to_jsonb(new) end,
      'old_record', case when tg_op <> 'INSERT' then to_jsonb(old) end,
      'actor', auth.uid()
    )
  );
  return null;
end;
$$;

revoke execute on function public.notify_change()
  from public, anon, authenticated;

create trigger expenses_notify_insert_delete
  after insert or delete on public.expenses
  for each row execute function public.notify_change();

-- Solo si algo cambió de verdad (guardar el formulario sin tocar nada no
-- avisa).
create trigger expenses_notify_update
  after update on public.expenses
  for each row
  when (old.* is distinct from new.*)
  execute function public.notify_change();

create trigger settlements_notify_insert
  after insert on public.settlements
  for each row execute function public.notify_change();

create trigger group_members_notify_insert
  after insert on public.group_members
  for each row execute function public.notify_change();
