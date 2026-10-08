# Chirpy

Chirpy is a native iOS social-feed demo where birds post about life in the flock. It is a sandbox for SwiftUI,
concurrency, networking, pagination, and testing.

<p align="center">
  <img src="docs/Images/feed.png" alt="Chirpy's social feed" width="320">
</p>

## Features

- Browse a reverse-chronological feed of bird posts
- Load more posts as you scroll
- Open a post to see its full text, image, and timestamp
- Create text-only posts
- Like and unlike posts
- Refresh with pull-to-refresh

Chirpy uses a shared demo profile for posts and likes. It does not require an account.

The backend also supports [paginated post search](https://github.com/samyanez94/Chirpy/wiki/Backend#search). The iOS
Search tab is planned separately.

## Built With

- Swift and SwiftUI
- Observation and Swift concurrency
- URLSession for networking
- Supabase Postgres, Storage, and Edge Functions
- Swift Testing and Deno tests

The project targets iOS 26.5 or later. This repository includes the iOS app and its backend.

## Running the Project

1. Clone the repository.
2. Copy `Chirpy/Configuration/LocalConfiguration.example.plist` to `Chirpy/Chirpy/LocalConfiguration.plist`.
3. Set `ChirpyAPIKey` in the copied file to the personal API key configured on the backend.
4. Open `Chirpy/Chirpy.xcodeproj` in a compatible Xcode version and select the `Chirpy` scheme.
5. Choose an iPhone Simulator or configure signing for your device, then build and run.

The app connects to the hosted Supabase project by default. You need its configured API key, or you can run your own
backend using the [backend guide](https://github.com/samyanez94/Chirpy/wiki/Backend). Keep the personal key private;
never use a Supabase service-role key in the app.

## Documentation

- [App Overview](https://github.com/samyanez94/Chirpy/wiki/App-Overview) — app behavior, the bird demo, and current
  limits.
- [Architecture](https://github.com/samyanez94/Chirpy/wiki/Architecture) — state, networking, and the backend.
- [Development](https://github.com/samyanez94/Chirpy/wiki/Development) — run and test the iOS app.
- [Backend](https://github.com/samyanez94/Chirpy/wiki/Backend) — Supabase setup, API reference, tests, and deployment.
