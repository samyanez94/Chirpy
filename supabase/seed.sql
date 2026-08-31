-- Deterministic and idempotent. Demo user: 00000000-0000-4000-8000-000000000001
insert into public.profiles (id, username, display_name, avatar_url, created_at) values
('00000000-0000-4000-8000-000000000001','sampler','Sam Rivera','https://i.pravatar.cc/256?u=chirpy-sampler','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000002','pixelpiper','Piper Lane','https://i.pravatar.cc/256?u=chirpy-piper','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000003','ari_builds','Ari Bell','https://i.pravatar.cc/256?u=chirpy-ari','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000004','noor_notes','Noor Hart','https://i.pravatar.cc/256?u=chirpy-noor','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000005','tinytrails','Emery Stone','https://i.pravatar.cc/256?u=chirpy-emery','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000006','keiko_codes','Keiko Vale','https://i.pravatar.cc/256?u=chirpy-keiko','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000007','mossandmaps','Robin Moss','https://i.pravatar.cc/256?u=chirpy-robin','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000008','devon_drafts','Devon Reed','https://i.pravatar.cc/256?u=chirpy-devon','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000009','luma_loop','Luma Park','https://i.pravatar.cc/256?u=chirpy-luma','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000010','cedarstack','Cedar Quinn','https://i.pravatar.cc/256?u=chirpy-cedar','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000011','jules_jots','Jules North','https://i.pravatar.cc/256?u=chirpy-jules','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000012','orbitolive','Olive Gray','https://i.pravatar.cc/256?u=chirpy-olive','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000013','marin_makes','Marin West','https://i.pravatar.cc/256?u=chirpy-marin','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000014','softsignal','Sasha Bloom','https://i.pravatar.cc/256?u=chirpy-sasha','2026-01-01T00:00:00Z'),
('00000000-0000-4000-8000-000000000015','tessellated','Tess Rowan','https://i.pravatar.cc/256?u=chirpy-tess','2026-01-01T00:00:00Z')
on conflict (id) do update set username=excluded.username, display_name=excluded.display_name, avatar_url=excluded.avatar_url;

insert into public.posts (id, author_id, body, image_url, created_at)
select
  ('10000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  ('00000000-0000-4000-8000-' || lpad((((n - 1) % 15) + 1)::text, 12, '0'))::uuid,
  (array[
    'Tried a smaller first step today. It worked.',
    'A quiet morning and a fresh page can fix a surprising amount.',
    'Today’s build note: clarity beats cleverness.',
    'Found a tiny trail with a very big view.',
    'The best debugging tool was a short walk.',
    'Shipping the simple version and taking notes.',
    'A good interface feels calm before it feels impressive.',
    'Coffee, a checklist, and one stubborn bug.',
    'Learning in public, one useful mistake at a time.',
    'Made room for an idea that was not ready yesterday.',
    'Small experiments are still progress.',
    'Today I remembered to celebrate the boring reliability wins.'
  ])[((n - 1) % 12) + 1] || ' #' || n,
  case when n % 5 = 0 then 'https://picsum.photos/seed/chirpy-' || n || '/1200/800' else null end,
  case when n between 1 and 6 then '2026-08-31T18:42:00Z'::timestamptz
       else '2026-08-31T18:42:00Z'::timestamptz - ((n - 6) * interval '7 hours') end
from generate_series(1, 120) as n
on conflict (id) do update set author_id=excluded.author_id, body=excluded.body, image_url=excluded.image_url, created_at=excluded.created_at;

insert into public.likes (user_id, post_id, created_at)
select
  ('00000000-0000-4000-8000-' || lpad(u::text, 12, '0'))::uuid,
  ('10000000-0000-4000-8000-' || lpad(p::text, 12, '0'))::uuid,
  '2026-08-31T19:00:00Z'::timestamptz
from generate_series(1, 15) u
cross join generate_series(1, 120) p
where (u * 7 + p * 3) % 17 < 3
on conflict do nothing;
