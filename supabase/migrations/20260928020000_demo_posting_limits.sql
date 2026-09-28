create index posts_author_created_at_idx on public.posts (author_id, created_at desc);

create or replace function public.create_post(p_demo_user_id uuid, p_text text)
returns table (id uuid, author_id uuid, username text, display_name text, avatar_url text,
               body text, image_url text, created_at timestamptz, is_liked boolean, like_count bigint)
language plpgsql security definer set search_path = public as $$
begin
  -- Lock the demo profile so concurrent requests share the same quota.
  perform 1 from public.profiles a where a.id = p_demo_user_id for update;
  if not found then raise exception 'Demo profile required' using errcode = '23503'; end if;
  if (select count(*) from public.posts p where p.author_id = p_demo_user_id and p.created_at > now() - interval '1 minute') >= 5
     or (select count(*) from public.posts p where p.author_id = p_demo_user_id and p.created_at > now() - interval '1 day') >= 50 then
    raise exception 'Posting limit exceeded' using errcode = 'P0429';
  end if;
  return query
    with inserted as (
      insert into public.posts (id, author_id, body) values (gen_random_uuid(), p_demo_user_id, p_text) returning *
    )
    select p.id, a.id, a.username, a.display_name, a.avatar_url,
           p.body, p.image_url, p.created_at, false, 0::bigint
    from inserted p join public.profiles a on a.id = p.author_id;
end;
$$;
revoke all on function public.create_post(uuid, text) from public, anon, authenticated;
grant execute on function public.create_post(uuid, text) to service_role;
