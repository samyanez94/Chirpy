begin;
do $$
begin
  assert has_column_privilege('service_role', 'public.profiles', 'id', 'SELECT');
  assert has_column_privilege('service_role', 'public.profiles', 'username', 'SELECT');
  assert has_column_privilege('service_role', 'public.profiles', 'display_name', 'SELECT');
  assert has_column_privilege('service_role', 'public.profiles', 'avatar_url', 'SELECT');
  assert not has_table_privilege('anon', 'public.profiles', 'SELECT');
  assert not has_table_privilege('authenticated', 'public.profiles', 'SELECT');
  assert not has_column_privilege('anon', 'public.profiles', 'id', 'SELECT');
  assert not has_column_privilege('authenticated', 'public.profiles', 'id', 'SELECT');
end;
$$;
-- Exercise the exact lookup fields under the role used by the Edge Function.
set local role service_role;
select id, username, display_name, avatar_url from public.profiles
where id = '00000000-0000-4000-8000-000000000001';
reset role;
rollback;
