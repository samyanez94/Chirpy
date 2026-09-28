create or replace function public.create_post(p_demo_user_id uuid, p_text text)
returns table (
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
security definer
set search_path = public
as $$
  with inserted as (
    insert into public.posts (id, author_id, body, image_url)
    values (gen_random_uuid(), p_demo_user_id, p_text, null)
    returning *
  )
  select p.id, a.id, a.username, a.display_name, a.avatar_url,
         p.body, p.image_url, p.created_at, false, 0::bigint
  from inserted p
  join public.profiles a on a.id = p.author_id;
$$;

revoke all on function public.create_post(uuid, text) from public, anon, authenticated;
grant execute on function public.create_post(uuid, text) to service_role;
