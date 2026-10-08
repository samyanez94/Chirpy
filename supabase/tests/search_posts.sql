begin;
do $$
declare
  demo uuid := gen_random_uuid();
  other_user uuid := gen_random_uuid();
  first_id uuid := '20000000-0000-4000-8000-000000000003';
  second_id uuid := '20000000-0000-4000-8000-000000000002';
  third_id uuid := '20000000-0000-4000-8000-000000000001';
  page record;
  found_ids uuid[];
  n integer;
begin
  insert into public.profiles (id, username, display_name, avatar_url)
  values (demo, 'search_test_' || substr(demo::text, 1, 8), 'Search Test', 'https://example.com/avatar.jpg'),
         (other_user, 'other_search_' || substr(other_user::text, 1, 8), 'Other Search Test', null);
  insert into public.posts (id, author_id, body, image_url, created_at)
  values (first_id, demo, 'ChirpySearchFixture Crumbs: 100% under_score path\crumbs', 'https://example.com/post.jpg', '2026-10-08T12:00:00.123456Z'),
         (second_id, demo, 'chirpysearchfixture bread crumbs', null, '2026-10-08T12:00:00.123456Z'),
         (third_id, demo, 'chirpysearchfixture crumbs', null, '2026-10-08T12:00:00.123455Z');
  insert into public.likes (user_id, post_id) values (demo, first_id), (other_user, first_id);

  select array_agg(s.id order by s.created_at desc, s.id desc) into found_ids
  from public.search_posts(demo, 'CHIRPYSEARCHFIXTURE', 50) s;
  assert found_ids = array[first_id, second_id, third_id], 'Case-insensitive matching or ordering failed';

  select * into page from public.search_posts(demo, 'ChirpySearchFixture', 1);
  assert page.id = first_id and page.author_id = demo, 'First page or author failed';
  assert page.username like 'search_test_%' and page.display_name = 'Search Test', 'Author fields missing';
  assert page.avatar_url = 'https://example.com/avatar.jpg' and page.image_url = 'https://example.com/post.jpg', 'URLs missing';
  assert page.is_liked and page.like_count = 2, 'Demo like state/count failed';
  assert page.created_at = '2026-10-08T12:00:00.123456Z'::timestamptz, 'Timestamp precision lost';

  select array_agg(s.id order by s.created_at desc, s.id desc) into found_ids
  from public.search_posts(demo, 'ChirpySearchFixture', 50, page.created_at, page.id) s;
  assert found_ids = array[second_id, third_id], 'Cursor tie-break or microseconds failed';

  select count(*) into n from public.search_posts(demo, 'ChirpySearchFixture', 50, '2026-10-08T12:00:00.123455Z', third_id);
  assert n = 0, 'Final page should be empty';
  select count(*) into n from public.search_posts(demo, 'NoSuchChirpySearchFixture', 50);
  assert n = 0, 'No-match result should be empty';

  select count(*) into n from public.search_posts(demo, '0%', 50) s where s.author_id = demo;
  assert n = 1, 'Percent must be literal';
  select count(*) into n from public.search_posts(demo, '_s', 50) s where s.author_id = demo;
  assert n = 1, 'Underscore must be literal';
  select count(*) into n from public.search_posts(demo, '\c', 50) s where s.author_id = demo;
  assert n = 1, 'Backslash must be literal';
  select count(*) into n from public.search_posts(demo, 'bread crumbs', 50) s where s.author_id = demo;
  assert n = 1, 'Phrase must match as one substring';
  select count(*) into n from public.search_posts(demo, 'CrUm', 50) s where s.author_id = demo;
  assert n = 3, 'Partial-word matching failed';
  select count(*) into n from public.search_posts(demo, ''' OR true --', 50) s where s.author_id = demo;
  assert n = 0, 'SQL text must be treated literally';

  update public.posts set body = 'ChirpySearchFixture 😀😀 café' where id = third_id;
  select count(*) into n from public.search_posts(demo, '😀😀', 50) s where s.author_id = demo;
  assert n = 1, 'Unicode matching failed';
  select count(*) into n from public.search_posts(demo, 'café', 50) s where s.author_id = demo;
  assert n = 1, 'Accented text matching failed';

  delete from public.likes where user_id = demo and post_id = first_id;
  select * into page from public.search_posts(demo, '100%', 1);
  assert not page.is_liked and page.like_count = 1, 'Other-user likes should count without marking the demo like';

  assert not has_function_privilege('anon', 'public.search_posts(uuid,text,integer,timestamptz,uuid)', 'EXECUTE');
  assert not has_function_privilege('authenticated', 'public.search_posts(uuid,text,integer,timestamptz,uuid)', 'EXECUTE');
  assert has_function_privilege('service_role', 'public.search_posts(uuid,text,integer,timestamptz,uuid)', 'EXECUTE');
  assert exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'posts_body_search_idx'
                 and indexdef like '%USING gin%'), 'Trigram GIN index missing';
end;
$$;
rollback;
