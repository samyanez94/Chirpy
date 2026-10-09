-- Public reads support the feed's existing image_url / AsyncImage flow.
-- Only trusted administrative tooling uploads; no client write policies.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chirpy-posts', 'chirpy-posts', true, 1048576, array['image/jpeg'])
on conflict (id) do nothing;
