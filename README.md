# Chirpy

Chirpy is a native iOS social-feed demo where birds post about life in the flock. It is a sandbox for SwiftUI,
concurrency, networking, pagination, and testing.

<p align="center">
  <img src="docs/Images/feed.png" alt="Chirpy's social feed" width="320">
</p>

## Features

- Browse a reverse-chronological feed of bird posts
- View the current profile and its posts
- Load more posts as you scroll
- Open a post to see its full text, image, and timestamp
- Create text-only posts
- Like and unlike posts
- Refresh with pull-to-refresh

Chirpy uses a shared demo profile for posts and likes. It does not require an account.

The Search tab supports [paginated post search](https://github.com/samyanez94/Chirpy/wiki/Backend#search).

## Built With

- Swift and SwiftUI
- Observation and Swift concurrency
- URLSession for networking
- Supabase Postgres, Storage, and Edge Functions
- Swift Testing and Deno tests

The iOS project targets iOS 26.5 or later. This repository contains the iOS client and its backend.
A future Android client can be added alongside `ios/` when development begins.

## Repository Structure

```text
Chirpy/
├── ios/
│   ├── Chirpy.xcodeproj
│   ├── Chirpy/              # App sources and assets
│   ├── ChirpyTests/         # Tests and fixtures
│   ├── Configuration/      # Local configuration template
│   └── .swift-format
├── supabase/               # Shared backend, tests, and demo data
│   ├── deno.json           # Backend tasks and tooling
│   └── deno.lock
└── docs/                   # Shared documentation assets
```

Each client owns its platform-specific code and build configuration. Backend Deno tooling lives in `supabase/`.

## Running the Project

1. Clone the repository.
2. Copy `ios/Configuration/LocalConfiguration.example.plist` to `ios/Chirpy/LocalConfiguration.plist`.
3. Set `ChirpyAPIKey` in the copied file to the personal API key configured on the backend.
4. Open `ios/Chirpy.xcodeproj` in a compatible Xcode version and select the `Chirpy` scheme.
5. Choose an iPhone Simulator or configure signing for your device, then build and run.

The app connects to the hosted Supabase project by default. You need its configured API key, or you can run your own
backend using the [backend guide](https://github.com/samyanez94/Chirpy/wiki/Backend). Keep the personal key private;
never use a Supabase service-role key in the app.

To run the iOS tests from the repository root, choose an installed simulator and run:

```sh
xcodebuild test -project ios/Chirpy.xcodeproj -scheme Chirpy \
  -destination 'platform=iOS Simulator,name=<simulator name>'
```

## Backend Development

Run the Deno tasks from `supabase/`:

```sh
cd supabase
deno task verify      # Type checks, lint, unit tests, and demo validation
deno task test:db     # SQL integration tests against the running local stack
deno task check       # Type-check Edge Functions and the seed generator
deno task test        # Run the social-feed tests
deno task demo:build  # Regenerate local demo SQL files
deno task demo:check  # Validate demo assets and generated SQL
```

From the repository root, you can also select the configuration explicitly, for example:
`deno task --config supabase/deno.json test`.

Continue running Supabase CLI commands and `sh supabase/scripts/publish_bird_demo.sh` from the repository root.
The demo build task only generates local files; publishing is a separate step.

## Documentation

- [App Overview](https://github.com/samyanez94/Chirpy/wiki/App-Overview) — app behavior, the bird demo, and current
  limits.
- [Architecture](https://github.com/samyanez94/Chirpy/wiki/Architecture) — state, networking, and the backend.
- [Development](https://github.com/samyanez94/Chirpy/wiki/Development) — run and test the iOS app.
- [Backend](https://github.com/samyanez94/Chirpy/wiki/Backend) — Supabase setup, API reference, tests, and deployment.
