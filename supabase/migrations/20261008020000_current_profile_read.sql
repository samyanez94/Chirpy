-- The Edge Function reads these fields directly using its service-role client.
-- Keep anon/authenticated access disabled and avoid exposing unused columns.
grant select (id, username, display_name, avatar_url) on public.profiles to service_role;
