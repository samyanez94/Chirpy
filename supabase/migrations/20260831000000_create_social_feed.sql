create table public.profiles (
  id uuid primary key,
  username text not null unique check (char_length(username) between 1 and 30 and username !~ '@'),
  display_name text not null check (char_length(display_name) between 1 and 80),
  avatar_url text,
  created_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key,
  author_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (char_length(btrim(body)) between 1 and 300),
  image_url text,
  created_at timestamptz not null default now()
);

create index posts_feed_order_idx on public.posts (created_at desc, id desc);

create table public.likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index likes_post_id_idx on public.likes (post_id);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;

-- No policies are intentional: anon/authenticated roles have no direct table access.
revoke all on public.profiles, public.posts, public.likes from anon, authenticated;

create or replace function public.feed_page(
  p_demo_user_id uuid,
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
  from posts p
  join profiles a on a.id = p.author_id
  left join likes l on l.post_id = p.id
  where p_cursor_created_at is null
     or p.created_at < p_cursor_created_at
     or (p.created_at = p_cursor_created_at and p.id < p_cursor_id)
  group by p.id, a.id
  order by p.created_at desc, p.id desc
  limit p_limit;
$$;

create or replace function public.set_post_like(
  p_demo_user_id uuid,
  p_post_id uuid,
  p_liked boolean
) returns table (post_exists boolean, is_liked boolean, like_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from posts where id = p_post_id) then
    return query select false, false, 0::bigint;
    return;
  end if;

  if p_liked then
    insert into likes (user_id, post_id) values (p_demo_user_id, p_post_id)
    on conflict do nothing;
  else
    delete from likes where user_id = p_demo_user_id and post_id = p_post_id;
  end if;

  return query
    select true,
           exists(select 1 from likes where user_id = p_demo_user_id and post_id = p_post_id),
           (select count(*) from likes where post_id = p_post_id);
end;
$$;

revoke all on function public.feed_page(uuid, integer, timestamptz, uuid) from public, anon, authenticated;
revoke all on function public.set_post_like(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.feed_page(uuid, integer, timestamptz, uuid) to service_role;
grant execute on function public.set_post_like(uuid, uuid, boolean) to service_role;
