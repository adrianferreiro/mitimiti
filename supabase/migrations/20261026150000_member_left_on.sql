-- Miembros dados de baja (#12): al eliminar la cuenta, la membresía con
-- gastos o pagos queda, pero con la fecha de baja. Los gastos posteriores ya
-- no se le reparten (lo calcula la app con lib/domain/balance.dart).

-- Día en que dejó el grupo; participa de los gastos hasta ese día inclusive.
-- Null = sigue en el grupo. Solo lo escribe delete_my_account().
alter table public.group_members add column left_on date;

-- La app es solo para Argentina: el "hoy" de la baja tiene que coincidir con
-- las fechas de los gastos, que se cargan en hora local (no UTC).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;

  -- Grupos donde es el único miembro: nadie más los ve, se borran enteros.
  delete from public.groups g
  where exists (
      select 1 from public.group_members m
      where m.group_id = g.id and m.user_id = uid
    )
    and not exists (
      select 1 from public.group_members m
      where m.group_id = g.id and m.user_id <> uid
    );

  -- En los grupos compartidos sale como si dejara el grupo, salvo donde tiene
  -- gastos o pagos: ahí la membresía queda (las FKs la necesitan y su parte
  -- del saldo tiene que seguir contando) pero dada de baja desde hoy.
  delete from public.group_members m
  where m.user_id = uid
    and not exists (
      select 1 from public.expenses e
      where e.group_id = m.group_id and e.paid_by = uid
    )
    and not exists (
      select 1 from public.settlements s
      where s.group_id = m.group_id
        and uid in (s.from_user_id, s.to_user_id)
    );

  update public.group_members
  set left_on = (now() at time zone 'America/Argentina/Buenos_Aires')::date
  where user_id = uid;

  delete from public.device_tokens where user_id = uid;
  delete from public.notification_prefs where user_id = uid;

  update public.profiles set display_name = 'Usuario eliminado'
  where id = uid;

  delete from auth.users where id = uid;
end;
$$;

-- Cuentas ya eliminadas antes de esta migración: dar de baja sus membresías
-- desde hoy.
update public.group_members m
set left_on = (now() at time zone 'America/Argentina/Buenos_Aires')::date
where m.left_on is null
  and not exists (select 1 from auth.users u where u.id = m.user_id);
