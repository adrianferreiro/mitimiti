-- La Edge Function `notify` usa la service role, que saltea RLS pero igual
-- necesita permisos de tabla (el proyecto no los da automáticamente a ningún
-- rol). Solo lo que la función lee o borra.
grant select on public.groups to service_role;
grant select on public.group_members to service_role;
grant select on public.profiles to service_role;
grant select on public.categories to service_role;
grant select, delete on public.device_tokens to service_role;
