begin;
do $$
declare
  demo uuid := gen_random_uuid();
  n integer;
begin
  insert into public.profiles (id, username, display_name) values (demo, 'quota_test_' || substr(demo::text, 1, 8), 'Quota Test');
  for n in 1..5 loop perform * from public.create_post(demo, 'Test'); end loop;
  begin
    perform * from public.create_post(demo, 'Over minute limit');
    raise exception 'Minute limit failed';
  exception when sqlstate 'P0429' then null;
  end;
  update public.posts set created_at = now() - interval '2 hours' where author_id = demo;
  insert into public.posts (id, author_id, body, created_at)
  select gen_random_uuid(), demo, 'Earlier test', now() - interval '2 hours' from generate_series(1, 45);
  begin
    perform * from public.create_post(demo, 'Over daily limit');
    raise exception 'Daily limit failed';
  exception when sqlstate 'P0429' then null;
  end;
  assert not has_function_privilege('anon', 'public.create_post(uuid,text)', 'EXECUTE');
  assert not has_function_privilege('authenticated', 'public.create_post(uuid,text)', 'EXECUTE');
end;
$$;
rollback;
