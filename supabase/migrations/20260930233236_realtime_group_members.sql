-- Que la app se entere en vivo cuando alguien se une o sale de un grupo.
alter publication supabase_realtime add table public.group_members;
