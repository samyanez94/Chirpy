# Chirpy

Chirpy is a small social-feed app where birds post about life in the flock. It is a sandbox for SwiftUI, concurrency,
networking, pagination, and testing.

This repo contains the iOS app and its Supabase backend. Three Edge Functions share one API handler using HTTP and JSON.

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

Configure the personal API key below, then open `Chirpy/Chirpy.xcodeproj`, choose an iPhone Simulator, and run. The app
uses the hosted Supabase project by default; running the backend locally is optional.

For a local backend, set `AppConfiguration.baseURL` in `Chirpy/Chirpy/AppConfiguration.swift` to
`http://127.0.0.1:54321` for the Simulator, or your Mac's local network address for a physical device.

## Personal API key

Data endpoints require `X-Chirpy-API-Key`; `/health` is public. The key controls access, while posts and likes use the
shared `DEMO_USER_ID`.

Copy `Chirpy/Configuration/LocalConfiguration.example.plist` to `Chirpy/Chirpy/LocalConfiguration.plist` and set
`ChirpyAPIKey` to the key configured on the backend. For a new local backend, generate a key with `openssl rand -hex 32`
and use the same value as `CHIRPY_API_KEY` in `supabase/functions/.env`. Both files are Git-ignored. Never use a
Supabase service-role key as the client key.

For hosted setup, set `CHIRPY_API_KEY` as a Supabase secret using the deployment steps below. To rotate it, update the
backend secret, local env file, and app plist, then rebuild. The key is embedded in the app; do not distribute a build
containing your personal key.

## Run the backend locally

You will need Docker, Supabase CLI 2.x, and Deno 2.x.

Start Supabase and build a fresh seeded database (`db reset` removes existing local data):

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

With `ENABLE_DEV_SCENARIOS=true`, add `scenario=slow`, `error`, `empty`, or `duplicates` to a feed request.

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

## Pagination

Posts are ordered by `created_at DESC, id DESC`. Pass the opaque `nextCursor` back unchanged to load the next page;
UUIDs break ties between posts with identical timestamps.

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

Success returns **201 Created** with a complete feed-style post, a database-generated ID and timestamp, no image, and
zero likes. Each successful POST creates a separate post, including repeated requests.

All clients post and like as Pip Sparrow (`@crumbclub`), the seeded `DEMO_USER_ID` profile. This profile must exist.
Posting is limited to five posts per rolling minute and 50 per rolling day, shared across all app installations.

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

The fictional flock has 15 bird profiles and 120 posts grounded in bird behavior.

Portraits are hosted in the public `chirpy-avatars` Supabase Storage bucket. The JPEGs in `supabase/assets/avatars/` are
publishing sources, not bundled app assets. See the [portrait guide](supabase/assets/README.md) for the cast, generation
prompts, and publishing steps.

Edit `supabase/demo/birds.json`, then regenerate the seed and the targeted update:

```sh
deno task demo:build
deno task demo:check
```

For an existing database, use `supabase/demo/refresh-bird-demo.sql` instead of a reset. It updates only the known seeded
profiles and posts, preserving timestamps, existing likes, and user-created posts. The fresh seed is still used by
`supabase db reset` when intentionally starting over.
