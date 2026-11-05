# Working on Chirpy

Chirpy has two native clients in `ios/` and `android/` that share a backend in `supabase/`. Use the [Chirpy Wiki](https://github.com/samyanez94/Chirpy/wiki) for project context. Read the page relevant to your task.

- [App Overview](https://github.com/samyanez94/Chirpy/wiki/App-Overview) covers the shared demo profile, user-facing features, and platform differences.
- [Architecture](https://github.com/samyanez94/Chirpy/wiki/Architecture) traces requests through both clients and the backend.
- [Backend](https://github.com/samyanez94/Chirpy/wiki/Backend) documents the API, local server setup, and database checks.
- [Design Notes](https://github.com/samyanez94/Chirpy/wiki/Design-Notes) explains decisions about pagination, concurrent updates, and Unicode limits.
- [Development](https://github.com/samyanez94/Chirpy/wiki/Development) covers setup, testing, and CI.

The Wiki describes `main`. Confirm behavior against the code and tests in your checkout. If the Wiki is unavailable, the [README](README.md) introduces the app, and the [CI workflows](.github/workflows) list the build and test commands for each platform.

When changing an API route or response, check how both native clients use it and run the relevant backend and client tests. For work under `android/`, also follow [the Android development standards](android/AGENTS.md).
