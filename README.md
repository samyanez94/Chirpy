# Chirpy

Chirpy is a small social-feed iOS app for practicing modern iOS development. It is a fun sandbox for SwiftUI, Swift
concurrency, networking, pagination, and testing.

This repo contains both the iOS app and its lightweight Supabase backend. The app talks to a single Edge Function using
plain HTTP and JSON.

<p align="center">
  <img src="docs/Images/feed.png" alt="Chirpy's social feed" width="320">
</p>

## What it does

- Shows a reverse-chronological feed
- Loads more posts with cursor pagination
- Creates text-only posts from the Home toolbar
- Likes and unlikes posts
- Refreshes with pull-to-refresh

The feed loads from the backend on each launch. Posts already on screen stay visible if a refresh fails.

The project intentionally skips accounts, replies, follows, search, notifications, and realtime updates.

## Run the app

You will need a recent Xcode version that supports the project's iOS 26.5 deployment target.

First, get the local backend running using the steps below. Then open `Chirpy/Chirpy.xcodeproj`, choose an iPhone
Simulator, and hit Run. The app currently points to the hosted Supabase project. For local development, set
`AppConfiguration.baseURL` to `http://127.0.0.1:54321`.

That address works from the Simulator. If you want to run Chirpy on a physical device, update the URL in
`Chirpy/Chirpy/AppConfiguration.swift` to your Mac's local network address and make sure the phone can reach it.

## Personal API key

Data endpoints require a dedicated random key in `X-Chirpy-API-Key`; `/health` remains public. The key gates personal
access and does not identify individual users. Posts and likes still use `DEMO_USER_ID`. No anonymous signup is
required.

Copy `Chirpy/Configuration/LocalConfiguration.example.plist` to `Chirpy/Chirpy/LocalConfiguration.plist`, then replace
`ChirpyAPIKey` with a random key generated using `openssl rand -hex 32`. The destination is Git-ignored and included in
local app builds. Set the same value as `CHIRPY_API_KEY` in the ignored `supabase/functions/.env` file. Never use the
Supabase service-role key as the client key. Missing client configuration fails before sending a request; missing server
configuration prevents function startup.

For hosted deployment, create a temporary ignored env file containing only `CHIRPY_API_KEY=...` and run
`supabase secrets set --env-file <path> --project-ref <project-ref>`. Do not upload local Supabase URLs or service keys.
Rotate the key by changing the hosted secret, local env file, and local app plist, then rebuilding the app. The key is
embedded in your personal app build; do not distribute that build or commit the plist.

## Run the backend locally

You will need Docker, Supabase CLI 2.x, and Deno 2.x.

Start Supabase and build a fresh seeded database:

```sh
supabase start
supabase db reset
```

Create the local function environment file:

```sh
cp supabase/functions/.env.example supabase/functions/.env
supabase status
```

Fill in these values in `supabase/functions/.env`:

| Name                        | Local value                                       |
| --------------------------- | ------------------------------------------------- |
| `SUPABASE_URL`              | `http://127.0.0.1:54321`                          |
| `SUPABASE_SERVICE_ROLE_KEY` | The local service-role key from `supabase status` |
| `CHIRPY_API_KEY`            | Your dedicated random personal API key            |
| `DEMO_USER_ID`              | `00000000-0000-4000-8000-000000000001`            |
| `ENABLE_DEV_SCENARIOS`      | `true`                                            |
| `ALLOWED_ORIGIN`            | Optional; usually blank for the iOS app           |

Never add the service-role key to the iOS app or commit `.env` files.

Serve the API:

```sh
supabase functions serve --env-file supabase/functions/.env --no-verify-jwt
```

## Try the API

Set `CHIRPY_API_KEY` in your shell to the configured key before making data requests.

```sh
curl http://127.0.0.1:54321/functions/v1/social-feed/health
curl -H "X-Chirpy-API-Key: $CHIRPY_API_KEY" 'http://127.0.0.1:54321/functions/v1/feed?limit=20'

curl -X POST -H "X-Chirpy-API-Key: $CHIRPY_API_KEY" \
  http://127.0.0.1:54321/functions/v1/posts/10000000-0000-4000-8000-000000000001/like

curl -X DELETE -H "X-Chirpy-API-Key: $CHIRPY_API_KEY" \
  http://127.0.0.1:54321/functions/v1/posts/10000000-0000-4000-8000-000000000001/like
```

Handy development feeds:

```text
/feed?scenario=slow
/feed?scenario=error
/feed?scenario=empty
/feed?scenario=duplicates
```

These only work when `ENABLE_DEV_SCENARIOS=true`.

## Run the backend tests

```sh
deno task test
deno task check
deno fmt --check
deno lint
```

## Run the iOS tests

Open the project in Xcode, pick an iPhone Simulator, and use **Product › Test** (`⌘U`). The test suite covers feed
state, pagination, networking, and likes.

## A quick note on pagination

Posts are ordered by `created_at DESC, id DESC`. Each response includes an opaque `nextCursor`; pass it back unchanged
to load the next page. The API uses keyset pagination, including UUID tie-breaking for posts with identical timestamps.

## Deploy the backend

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase functions deploy social-feed --no-verify-jwt
supabase functions deploy feed --no-verify-jwt
supabase functions deploy posts --no-verify-jwt
supabase secrets set --env-file path/to/production.env
# Include CHIRPY_API_KEY and DEMO_USER_ID; never upload your local service-role key.
```

Keep development scenarios disabled in production. `supabase db push` does not run `seed.sql`, so seed a hosted demo
project separately only if you want the fictional content there.

## Create a post

`POST /functions/v1/posts` accepts only a `text` string. The same endpoint is available at
`/functions/v1/social-feed/posts`.

```sh
curl -X POST http://127.0.0.1:54321/functions/v1/posts \
  -H 'Content-Type: application/json' \
  -H "X-Chirpy-API-Key: $CHIRPY_API_KEY" \
  -d '{"text":"Hello from Chirpy!"}'
```

Text is trimmed at both ends and must contain 1–300 Unicode code points after trimming. Internal whitespace and line
breaks are preserved. Attachments, author IDs, and other extra fields are rejected.

A successful request returns **201 Created** with a complete post directly, using the same shape as a feed item: `id`,
`author`, `text`, `imageURL`, `createdAt`, `isLiked`, and `likeCount`. The database generates the ID and timestamp; new
posts have `imageURL: null`, `isLiked: false`, and `likeCount: 0`.

All posts are authored by the server's `DEMO_USER_ID`, currently the seeded Pip Sparrow (`@crumbclub`) profile. All
clients share that identity for both posting and liking. The profile must already exist. This is intended for
local/private demos; there is no authentication or per-user identity. Each successful POST creates a new post, including
repeated requests. Creation is limited to five posts per rolling minute and 50 per rolling day for the shared demo
profile, including concurrent requests. These limits are shared by all app installations.

Errors retain the existing `{ "error": { "code", "message", "requestID" } }` envelope:

- **400 `invalid_request`**: malformed JSON, invalid text, or unsupported fields.
- **401 `unauthorized`**: missing or incorrect personal API key.
- **429 `rate_limit_exceeded`**: the shared posting limit was reached.
- **405 `method_not_allowed`**: unsupported HTTP method.
- **500 `internal_error`**: database or configuration failure, including a missing demo profile.

For an existing local database, apply pending migrations without resetting its data:

```sh
supabase migration up --local
```

## The bird demo

The fictional flock has 15 bird profiles and 120 distinct posts grounded in bird behavior. Pip Sparrow is the shared
posting identity. Existing demo UUIDs, timestamp ties, and like relationships are retained.

Portraits are hosted in the public `chirpy-avatars` Supabase Storage bucket. The 512 × 512 JPEGs in
`supabase/assets/avatars/` are publishing sources; they are **not bundled with the iOS app**. See
[`supabase/assets/README.md`](supabase/assets/README.md) for the cast, generation prompts, and publishing steps.

Edit `supabase/demo/birds.json`, then regenerate the seed and the targeted update:

```sh
deno task demo:build
deno task demo:check
```

For an existing database, use `supabase/demo/refresh-bird-demo.sql` instead of a reset. It updates only the known seeded
profiles and posts, preserving timestamps, existing likes, and user-created posts. The fresh seed is still used by
`supabase db reset` when intentionally starting over.
