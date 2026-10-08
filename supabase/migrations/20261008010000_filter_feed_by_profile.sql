-- Replace the old signature to avoid ambiguous PostgREST RPC overloads.
drop function public.feed_page(uuid, integer, timestamptz, uuid);

drop index public.posts_author_created_at_idx;
create index posts_author_created_at_idx on public.posts (author_id, created_at desc, id desc);

create or replace function public.feed_page(
  p_demo_user_id uuid,
  p_limit integer,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null,
  p_profile_id uuid default null
) returns table (
  id uuid,
  author_id uuid,
  username text,
  display_name text,
  avatar_url text,
  body text,
  image_url text,
  created_at timestamptz,
  is_liked boolean,
  like_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, a.id, a.username, a.display_name, a.avatar_url,
         p.body, p.image_url, p.created_at,
         coalesce(bool_or(l.user_id = p_demo_user_id), false) as is_liked,
         count(l.user_id) as like_count
  from posts p
  join profiles a on a.id = p.author_id
  left join likes l on l.post_id = p.id
  where (p_profile_id is null or p.author_id = p_profile_id)
    and (p_cursor_created_at is null
      or p.created_at < p_cursor_created_at
      or (p.created_at = p_cursor_created_at and p.id < p_cursor_id))
  group by p.id, a.id
  order by p.created_at desc, p.id desc
  limit p_limit;
$$;

revoke all on function public.feed_page(uuid, integer, timestamptz, uuid, uuid) from public, anon, authenticated;
grant execute on function public.feed_page(uuid, integer, timestamptz, uuid, uuid) to service_role;
