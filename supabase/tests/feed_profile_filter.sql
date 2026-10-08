begin;
do $$
declare
  viewer uuid := gen_random_uuid();
  author uuid := gen_random_uuid();
  empty_profile uuid := gen_random_uuid();
  first_id uuid := '30000000-0000-4000-8000-000000000003';
  second_id uuid := '30000000-0000-4000-8000-000000000002';
  third_id uuid := '30000000-0000-4000-8000-000000000001';
  other_id uuid := gen_random_uuid();
  found_ids uuid[];
  page record;
  n integer;
begin
  insert into public.profiles (id, username, display_name)
  values (viewer, 'feed_viewer_' || substr(viewer::text, 1, 8), 'Viewer'),
         (author, 'feed_author_' || substr(author::text, 1, 8), 'Author'),
         (empty_profile, 'feed_empty_' || substr(empty_profile::text, 1, 8), 'Empty');
  insert into public.posts (id, author_id, body, created_at)
  values (first_id, author, 'First', '2026-10-08T12:00:00.123456Z'),
         (second_id, author, 'Second', '2026-10-08T12:00:00.123456Z'),
         (third_id, author, 'Third', '2026-10-08T12:00:00.123455Z'),
         (other_id, viewer, 'Other author', '2026-10-08T12:01:00Z');
  insert into public.likes (user_id, post_id) values (viewer, first_id), (author, first_id), (author, second_id);

  select array_agg(f.id order by f.created_at desc, f.id desc) into found_ids
  from public.feed_page(viewer, 50, null, null, author) f;
  assert found_ids = array[first_id, second_id, third_id], 'Author filtering or ordering failed';
  select * into page from public.feed_page(viewer, 1, null, null, author);
  assert page.id = first_id and page.author_id = author and page.display_name = 'Author', 'Author fields failed';
  assert page.is_liked and page.like_count = 2, 'Viewer like state or count failed';
  assert page.created_at = '2026-10-08T12:00:00.123456Z'::timestamptz, 'Timestamp precision lost';
  select array_agg(f.id order by f.created_at desc, f.id desc) into found_ids
  from public.feed_page(viewer, 50, page.created_at, page.id, author) f;
  assert found_ids = array[second_id, third_id], 'Cursor tie-break or microsecond ordering failed';
  select * into page from public.feed_page(viewer, 1, page.created_at, page.id, author);
  assert not page.is_liked and page.like_count = 1, 'Author likes must not mark viewer likes';
  select count(*) into n from public.feed_page(viewer, 50, '2026-10-08T12:00:00.123455Z', third_id, author);
  assert n = 0, 'Final page should be empty';
  select count(*) into n from public.feed_page(viewer, 50, null, null, empty_profile);
  assert n = 0, 'Empty profile should return no posts';
  select count(*) into n from public.feed_page(viewer, 50, null, null, gen_random_uuid());
  assert n = 0, 'Unknown profile should return no posts';
  -- Existing positional calls still work without the optional filter.
  select count(*) into n from public.feed_page(viewer, 1000) f
  where f.id = any(array[first_id, second_id, third_id, other_id]);
  assert n = 4, 'Unfiltered feed omitted an author';

  assert not has_function_privilege('anon', 'public.feed_page(uuid,integer,timestamptz,uuid,uuid)', 'EXECUTE');
  assert not has_function_privilege('authenticated', 'public.feed_page(uuid,integer,timestamptz,uuid,uuid)', 'EXECUTE');
  assert has_function_privilege('service_role', 'public.feed_page(uuid,integer,timestamptz,uuid,uuid)', 'EXECUTE');
  assert exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'posts_author_created_at_idx'
    and indexdef like '%(author_id, created_at DESC, id DESC)%'), 'Author pagination index missing';
end;
$$;
rollback;
