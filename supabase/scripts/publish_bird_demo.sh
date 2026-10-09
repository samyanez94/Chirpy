#!/bin/sh
set -eu

# Run from the repository root after resuming the hosted Chirpy project.
# Use the authenticated CLI; never put service-role keys in the app or this script.
chirpy_project_ref=ncmomgqxdwrjwmoihayz
deno task demo:check
chirpy_download=$(mktemp)
trap 'rm -f "$chirpy_download"' EXIT HUP INT TERM

publish_image() {
  chirpy_source=$1
  chirpy_bucket=$2
  chirpy_filename=$(basename "$chirpy_source")
  chirpy_status=$(curl --silent --show-error --output "$chirpy_download" --write-out '%{http_code}' \
    "https://$chirpy_project_ref.supabase.co/storage/v1/object/public/$chirpy_bucket/$chirpy_filename")
  case "$chirpy_status" in
    200)
      if cmp -s "$chirpy_source" "$chirpy_download"; then
        echo "Already published: $chirpy_bucket/$chirpy_filename"
        return
      fi
      echo "Published content differs: $chirpy_filename. Use a new versioned filename." >&2
      exit 1
      ;;
    404) ;;
    400)
      # Storage wraps missing objects in HTTP 400 with an explicit NoSuchKey body.
      deno eval 'const e = JSON.parse(await Deno.readTextFile(Deno.args[0]));
        if (String(e.statusCode) !== "404" || e.code !== "NoSuchKey") Deno.exit(1)' "$chirpy_download" || {
        echo "Could not check $chirpy_bucket/$chirpy_filename: HTTP $chirpy_status" >&2
        exit 1
      }
      ;;
    *) echo "Could not check $chirpy_bucket/$chirpy_filename: HTTP $chirpy_status" >&2; exit 1 ;;
  esac
  supabase storage cp --experimental --linked --project-ref "$chirpy_project_ref" \
    --content-type image/jpeg --cache-control 'max-age=31536000' \
    "$chirpy_source" "ss:///$chirpy_bucket/$chirpy_filename"
}

# Bucket creation is idempotent. The migration can also be applied by db push.
supabase db query --linked --project-ref "$chirpy_project_ref" \
  --file supabase/migrations/20261007000000_create_bird_avatars_bucket.sql
supabase db query --linked --project-ref "$chirpy_project_ref" \
  --file supabase/migrations/20261009010000_create_bird_posts_bucket.sql

# Publish all images before changing profile URLs. Versioned paths allow long caching.
for chirpy_avatar in supabase/assets/avatars/*-v1.jpg; do
  publish_image "$chirpy_avatar" chirpy-avatars
done

# Publish feed attachments before changing post URLs, using the validated manifest.
deno eval 'for (const image of JSON.parse(await Deno.readTextFile("supabase/assets/post-prompts.json"))) console.log(image.file)' |
while IFS= read -r chirpy_post_file; do
  publish_image "supabase/assets/posts/$chirpy_post_file" chirpy-posts
done

# Only known seeded rows are updated. Timestamps, likes, and new posts are preserved.
supabase db query --linked --project-ref "$chirpy_project_ref" \
  --file supabase/demo/refresh-bird-demo.sql
