-- handle_new_user solo debe correr como trigger de auth.users; no exponerla
-- como RPC.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
