create or replace function public.delete_post(p_demo_user_id uuid, p_post_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  with deleted as (
    delete from public.posts
    where id = p_post_id and author_id = p_demo_user_id
    returning id
  )
  select exists(select 1 from deleted);
$$;

revoke all on function public.delete_post(uuid, uuid) from public, anon, authenticated;
grant execute on function public.delete_post(uuid, uuid) to service_role;
