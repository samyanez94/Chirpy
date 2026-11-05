# Development reference

See the [project README](../README.md#getting-started) to run either app.
This reference keeps the local commands and CI details together.

## iOS tests

From the repository root, choose an installed iPhone simulator and run:

```sh
xcodebuild test -project ios/Chirpy.xcodeproj -scheme Chirpy \
  -destination 'platform=iOS Simulator,name=<simulator name>'
```

In Xcode, you can also use **Product → Test**. Client tests do not require a hosted backend.

## Android development

Use JDK 17 or newer supported by the Gradle wrapper. Gradle provisions its daemon JDK
from the committed toolchain configuration. Android Studio creates `local.properties`
with your SDK location.

For a local backend on the Android emulator, set
`CHIRPY_BASE_URL=http://10.0.2.2:54321/` in `android/chirpy.properties` and use the local
backend's Chirpy API key. Environment variables override values in that file.
Both local property files are Git-ignored. Release builds require HTTPS.

From `android/`:

```sh
./gradlew format
./gradlew qualityCheck
./gradlew fullValidation
./gradlew connectedDebugAndroidTest
```

`qualityCheck` runs formatting checks, detekt, Android Lint, JVM tests, and the debug build.
`fullValidation` also builds the optimized release APK. Neither requires an API key or server.
UI tests require a running emulator; use API 35, matching CI. The pinned Espresso dependency
has an input-injection compatibility issue on API 37.

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

## Continuous integration

GitHub Actions validates all three projects on every pull request, push to `main`, and manual run.
New pushes cancel superseded runs for the same workflow and branch. CI uses no production secrets
and does not deploy the backend or publish apps.

| Required check | Validation | Local equivalent |
| --- | --- | --- |
| Supabase validation | Type checks, lint, unit tests, demo data, fresh migrations/seed, SQL integration tests | In `supabase/`: `deno task verify`, then `deno task test:db` against a running local stack |
| iOS validation | Swift formatting, simulator tests, Release compilation | Commands below |
| Android validation | Formatting, detekt, lint, JVM tests, debug and optimized Release APKs | In `android/`: `./gradlew fullValidation` |
| Android UI tests | Compose tests on an API 35 emulator | In `android/`: `./gradlew connectedDebugAndroidTest` |

For iOS, from the repository root:

```sh
xcrun swift-format lint --strict --recursive ios/Chirpy ios/ChirpyTests
xcodebuild test -project ios/Chirpy.xcodeproj -scheme Chirpy \
  -destination 'platform=iOS Simulator,name=<simulator name>' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project ios/Chirpy.xcodeproj -scheme Chirpy \
  -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

CI selects Xcode 26.6 and reuses an available iOS 26.5 runtime and iPhone simulator (preferring iPhone 17 Pro).
It downloads the runtime or creates a simulator only when missing. Backend tooling is pinned to Deno 2.9.5
and Supabase CLI 2.115.0. Android uses JDK 17 for SDK tools and analysis; Gradle automatically
provisions JetBrains JDK 25 according to its committed daemon criteria. Action revisions are pinned.

Test/analysis reports and failure diagnostics are available as workflow artifacts for seven days.
The iOS tests use stubbed clients; CI omits the optional local API-key configuration. Backend SQL
tests run only against the ephemeral local database. Client tests do not require a hosted backend.

Require the four checks above in the `main` branch protection settings after their first successful
runs. Workflow files alone do not enforce merge restrictions. Keep required workflows running on
all pull requests; adding path filters can leave required checks pending.
