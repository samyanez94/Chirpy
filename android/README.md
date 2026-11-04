# Chirpy for Android

The first vertical slice is Home: cursor pagination, pull-to-refresh, author portraits, post images,
server-confirmed likes, and loading/empty/error/retry states. Search, Profile, post detail, and composition
are intentionally deferred. Post rows do not navigate yet.

## Run

1. Open this directory in Android Studio. Use JDK 17 or newer supported by Gradle 9.8.2.
2. Install Android SDK Platform 37.0 and Build Tools 36.0.0. Minimum device version is Android 8 (API 26).
3. Copy `chirpy.properties.example` to `chirpy.properties` and set `CHIRPY_API_KEY` to the demo key.
4. Sync Gradle and run the `app` configuration. Missing keys produce a configuration error on Home.

Android Studio creates `local.properties` with your SDK location. Both local property files are ignored.
Environment variables `CHIRPY_API_KEY` and `CHIRPY_BASE_URL` override the corresponding file values.
The key is bundled in the APK, just as on iOS; it is not a per-user identity. Never use a service-role key.

For the local Supabase stack, start it from the repository root and set
`CHIRPY_BASE_URL=http://10.0.2.2:54321/` for an Android emulator. Use the local stack's Chirpy key.
Debug cleartext access is restricted to emulator/loopback addresses; release builds require HTTPS.

## Verify

From this directory:

```sh
./gradlew format                         # Apply ktlint to Kotlin and Gradle Kotlin scripts
./gradlew qualityCheck                   # ktlint, detekt, Android Lint, JVM tests, debug APK
./gradlew fullValidation                 # qualityCheck plus optimized release APK
./gradlew connectedDebugAndroidTest      # UI tests on a running emulator/device
```

`qualityCheck` (`verify` is an alias) requires no API key, server, or emulator. Network tests use MockWebServer; UI tests use fixed state.
GitHub Actions runs fullValidation and a separate API 35 emulator test job.
Use an API 35 emulator for UI tests, matching CI. The pinned stable Espresso dependency currently fails
to initialize input injection on API 37; this does not prevent running the app on Android 17.
Build output: `app/build/outputs/apk/debug/app-debug.apk`.
Release builds enable R8 optimization and resource shrinking. Run `./gradlew assembleRelease` to
build an unsigned release APK; production signing is not configured yet.

## Architecture and style

- `app`: dependency construction and the activity. Dependencies use constructor injection.
- `core/model`: immutable application models, independent of HTTP and Compose.
- `core/data`: repository contract and typed failures.
- `core/network`: Retrofit, serialization DTOs, error mapping, and the repository implementation.
- `core/ui`: theme and reusable post presentation.
- `feature/feed`: ViewModel, immutable state, lifecycle-aware route, and stateless screen.

The screen renders state and sends actions. The ViewModel owns pagination and per-post mutation state;
only the repository performs network requests. Generation checks reject superseded results. Like responses
are authoritative, and a late refresh cannot replace a like completed after that refresh started.
Rotation preserves the ViewModel and list position; process recreation reloads Home. No persistent feed
cache or background retry queue is introduced in this slice.

ktlint **1.8.0** is the only formatter, configured through `.editorconfig` using the IntelliJ IDEA
code style and Kotlin official IDE defaults (four spaces, 100 columns). Composable functions retain
Google's PascalCase naming convention. Disable the old ktfmt IDE formatter to avoid competing edits.
Tool versions are pinned in the version catalog. CLI tasks run in isolated JDK 17 processes;
Gradle toolchains can download JDK 17 automatically on the first run.

See `AGENTS.md` for code review rules. Favor explicit state, descriptive names, small cohesive functions,
and comments that explain decisions. Do not suppress lint or introduce abstractions solely to pass checks.

## Automated quality gates

- `./gradlew ktlintCheck` / `./gradlew ktlintFormat`: check/fix all Kotlin source and Gradle scripts,
  excluding generated build and Gradle-cache directories.
- `./gradlew detekt`: syntax-based analysis of production, JVM-test, and instrumented-test Kotlin.
  Reports are written to `build/reports/detekt/` in HTML and SARIF formats.
- `./gradlew :app:lintDebug :app:lintRelease`: Android Lint for both variants, with warnings treated as errors and no baseline.
- `./gradlew :app:testDebugUnitTest`: existing JUnit/coroutine/MockWebServer tests.
- `./gradlew qualityCheck`: all of the above plus debug compilation and APK assembly. Any failed
  tool exits nonzero and fails the aggregate task. CLI checks intentionally run on every invocation.
- `./gradlew fullValidation`: adds the R8-optimized release build. Emulator checks
  remain separate because they require a running device and are substantially slower.

`config/detekt.yml` deliberately selects non-formatting rules for complexity, nesting, parameter counts,
empty catches, global coroutines, unreachable code, and selected code smells. Compose rendering
functions are exempt from the line-count rule (not complexity checks); test classes are exempt from
function-count limits. These are framework-aware policies, not per-file suppressions. There are no
baselines or remaining accepted violations.

### Compatibility limitation

The build remains on AGP 9.5.0, Kotlin 2.4.21, and Gradle 9.8.2. Stable detekt **1.23.8** embeds
Kotlin 2.0.21 and its Gradle plugin predates AGP 9. It runs via its standalone CLI to avoid loading
that compiler into the Android build. Analysis is **syntax-only**, verified on this source tree;
we do not claim support for all Kotlin 2.4 syntax or type-resolved rules. Revisit this integration
when a stable detekt release supports the current Kotlin compiler. Android Lint and compilation
continue to provide type-aware checks. No alpha tool or compiler downgrade is introduced.

References: [detekt compatibility](https://detekt.dev/docs/1.23.8/introduction/compatibility/),
[detekt CLI](https://detekt.dev/docs/1.23.8/gettingstarted/cli/),
[ktlint releases](https://github.com/ktlint/ktlint/releases),
[Kotlin conventions](https://kotlinlang.org/docs/coding-conventions.html),
[Android architecture](https://developer.android.com/topic/architecture/recommendations).

### GitHub required check

After pushing the workflow and allowing its first run, open **Settings → Rules → Rulesets** (or
**Branches → Branch protection rules**) for `main`. Require pull requests and status checks, and
select **Android quality** from the GitHub Actions checks. Also require **Android UI tests**, **iOS quality**, and **Supabase quality**.
The workflow runs on every pull request and push to main, so path filtering cannot leave a required
check pending for iOS-only changes. Repository administrators must enable this rule; committing the
workflow alone does not prevent merging. See the repository README for the cross-platform CI commands and reports.

## Review checklist

- Scroll through multiple pages; IDs remain unique and paging stops at the end.
- Refresh populated and empty feeds; failed refreshes preserve content.
- Retry initial and pagination errors; invalid cursors restart pagination.
- Tap a like repeatedly; only one request is active and errors leave the previous value intact.
- Rotate, switch light/dark mode, increase font size, and inspect TalkBack labels.
- Inspect the boundary between FeedScreen, FeedViewModel, and FeedRepository before expanding the app.
