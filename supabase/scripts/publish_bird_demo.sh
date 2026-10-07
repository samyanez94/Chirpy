#!/bin/sh
set -eu

# Run from the repository root after resuming the hosted Chirpy project.
# Use the authenticated CLI; never put service-role keys in the app or this script.
chirpy_project_ref=ncmomgqxdwrjwmoihayz
deno task demo:check

# Bucket creation is idempotent. The migration can also be applied by db push.
supabase db query --linked --project-ref "$chirpy_project_ref" \
  --file supabase/migrations/20261007000000_create_bird_avatars_bucket.sql

# Publish all images before changing profile URLs. Versioned paths allow long caching.
for chirpy_avatar in supabase/assets/avatars/*-v1.jpg; do
  supabase storage cp --experimental --linked --project-ref "$chirpy_project_ref" \
    --content-type image/jpeg --cache-control 'max-age=31536000' \
    "$chirpy_avatar" "ss:///chirpy-avatars/$(basename "$chirpy_avatar")"
done

# Only known seeded rows are updated. Timestamps, likes, and new posts are preserved.
supabase db query --linked --project-ref "$chirpy_project_ref" \
  --file supabase/demo/refresh-bird-demo.sql
