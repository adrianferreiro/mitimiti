-- Eliminar la cuenta desde la app (App Store 5.1.1(v) y Google Play).
-- Se borra el usuario de Auth (email, identidades, sesiones), pero su perfil
-- queda anonimizado como "Usuario eliminado": sus gastos y pagos en grupos
-- compartidos siguen ahí, así el saldo de los demás no cambia.

-- El perfil ya no se borra en cascada con auth.users.
alter table public.profiles drop constraint profiles_id_fkey;

create function public.delete_my_account()
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
  -- del saldo tiene que seguir contando).
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

  delete from public.device_tokens where user_id = uid;
  delete from public.notification_prefs where user_id = uid;

  update public.profiles set display_name = 'Usuario eliminado'
  where id = uid;

  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
