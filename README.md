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
- Creates text-only posts through the backend API
- Likes and unlikes posts
- Refreshes with pull-to-refresh

The feed loads from the backend on each launch. Posts already on screen stay visible if a refresh fails.

The project intentionally skips accounts, a post composer, replies, follows, search, notifications, and realtime
updates.

## Run the app

You will need a recent Xcode version that supports the project's iOS 26.5 deployment target.

First, get the local backend running using the steps below. Then open `Chirpy/Chirpy.xcodeproj`, choose an iPhone
Simulator, and hit Run. The app is already set up to talk to Supabase at `http://127.0.0.1:54321`.

That address works from the Simulator. If you want to run Chirpy on a physical device, update the URL in
`Chirpy/Chirpy/AppConfiguration.swift` to your Mac's local network address and make sure the phone can reach it.

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
| `DEMO_USER_ID`              | `00000000-0000-4000-8000-000000000001`            |
| `ENABLE_DEV_SCENARIOS`      | `true`                                            |
| `ALLOWED_ORIGIN`            | Optional; usually blank for the iOS app           |

Never add the service-role key to the iOS app or commit `.env` files.

Serve the API:

```sh
supabase functions serve --env-file supabase/functions/.env --no-verify-jwt
```

## Try the API

```sh
curl http://127.0.0.1:54321/functions/v1/social-feed/health
curl 'http://127.0.0.1:54321/functions/v1/feed?limit=20'

curl -X POST \
  http://127.0.0.1:54321/functions/v1/posts/10000000-0000-4000-8000-000000000001/like

curl -X DELETE \
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
```

Keep development scenarios disabled in production. `supabase db push` does not run `seed.sql`, so seed a hosted demo
project separately only if you want the fictional content there.

## Create a post

`POST /functions/v1/posts` accepts only a `text` string. The same endpoint is available at
`/functions/v1/social-feed/posts`.

```sh
curl -X POST http://127.0.0.1:54321/functions/v1/posts \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello from Chirpy!"}'
```

Text is trimmed at both ends and must contain 1–300 Unicode code points after trimming. Internal whitespace and line
breaks are preserved. Attachments, author IDs, and other extra fields are rejected.

A successful request returns **201 Created** with a complete post directly, using the same shape as a feed item: `id`,
`author`, `text`, `imageURL`, `createdAt`, `isLiked`, and `likeCount`. The database generates the ID and timestamp; new
posts have `imageURL: null`, `isLiked: false`, and `likeCount: 0`.

All posts are authored by the server's `DEMO_USER_ID`, currently the seeded Sam Rivera (`@sampler`) profile. All clients
share that identity for both posting and liking. The profile must already exist. This is intended for local/private
demos; there is no authentication or per-user identity. Each successful POST creates a new post, including repeated
requests.

Errors retain the existing `{ "error": { "code", "message", "requestID" } }` envelope:

- **400 `invalid_request`**: malformed JSON, invalid text, or unsupported fields.
- **405 `method_not_allowed`**: unsupported HTTP method.
- **500 `internal_error`**: database or configuration failure, including a missing demo profile.

For an existing local database, apply pending migrations without resetting its data:

```sh
supabase migration up --local
```
