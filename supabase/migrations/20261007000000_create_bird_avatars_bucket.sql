-- Public reads let the iOS app load avatars through its existing AsyncImage flow.
-- No client upload policies: only trusted administrative tooling publishes assets.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chirpy-avatars', 'chirpy-avatars', true, 262144, array['image/jpeg'])
on conflict (id) do nothing;
