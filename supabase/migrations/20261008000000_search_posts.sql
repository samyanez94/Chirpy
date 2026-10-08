create extension if not exists pg_trgm with schema extensions;

create index posts_body_search_idx on public.posts using gin (body extensions.gin_trgm_ops);

create or replace function public.search_posts(
  p_demo_user_id uuid,
  p_query text,
  p_limit integer,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
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
  from public.posts p
  join public.profiles a on a.id = p.author_id
  left join public.likes l on l.post_id = p.id
  -- Escape LIKE metacharacters so the entire query is a literal substring.
  where p.body ilike '%' || replace(replace(replace(p_query, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_') || '%' escape E'\\'
    and (p_cursor_created_at is null
      or p.created_at < p_cursor_created_at
      or (p.created_at = p_cursor_created_at and p.id < p_cursor_id))
  group by p.id, a.id
  order by p.created_at desc, p.id desc
  limit p_limit;
$$;

revoke all on function public.search_posts(uuid, text, integer, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.search_posts(uuid, text, integer, timestamptz, uuid) to service_role;
