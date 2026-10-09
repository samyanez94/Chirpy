begin;
do $$
declare
  demo uuid := gen_random_uuid();
  other_author uuid := gen_random_uuid();
  own_post uuid := gen_random_uuid();
  other_post uuid := gen_random_uuid();
begin
  insert into public.profiles (id, username, display_name) values
    (demo, 'delete_' || substr(demo::text, 1, 8), 'Deletion Test'),
    (other_author, 'delete_' || substr(other_author::text, 1, 8), 'Other Author');
  insert into public.posts (id, author_id, body) values
    (own_post, demo, 'Own post'), (other_post, other_author, 'Other post');
  insert into public.likes (user_id, post_id) values (demo, own_post), (other_author, own_post);

  assert not public.delete_post(demo, other_post), 'Another author''s post must not be deleted';
  assert exists(select 1 from public.posts where id = other_post);
  assert not public.delete_post(demo, gen_random_uuid()), 'Missing posts return false';
  assert public.delete_post(demo, own_post), 'Own post must be deleted';
  assert not exists(select 1 from public.posts where id = own_post);
  assert not exists(select 1 from public.likes where post_id = own_post), 'All likes must cascade';
  assert not public.delete_post(demo, own_post), 'Repeated deletion returns false';
  assert not exists(select 1 from public.feed_page(demo, 50) where id = own_post);
  assert not exists(select 1 from public.search_posts(demo, 'Own post', 50) where id = own_post);

  -- Deletion frees a posting slot because quotas count surviving posts.
  for i in 1..5 loop perform * from public.create_post(demo, 'Quota fixture'); end loop;
  begin
    perform * from public.create_post(demo, 'Over quota');
    raise exception 'Minute limit failed';
  exception when sqlstate 'P0429' then null;
  end;
  select id into own_post from public.posts where author_id = demo limit 1;
  assert public.delete_post(demo, own_post);
  perform * from public.create_post(demo, 'Slot restored');
  assert (select count(*) from public.posts where author_id = demo) = 5;

  assert not has_function_privilege('anon', 'public.delete_post(uuid,uuid)', 'EXECUTE');
  assert not has_function_privilege('authenticated', 'public.delete_post(uuid,uuid)', 'EXECUTE');
  assert has_function_privilege('service_role', 'public.delete_post(uuid,uuid)', 'EXECUTE');
  assert not has_table_privilege('anon', 'public.posts', 'DELETE');
  assert not has_table_privilege('authenticated', 'public.posts', 'DELETE');
end;
$$;
rollback;
