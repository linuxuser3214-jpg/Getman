# E2E Testing Harness (Patrol, macOS desktop) — Design

**Date:** 2026-06-15
**Status:** Approved (approach A)

## Goal

Replace manual pre-publish click-testing with an automated end-to-end suite
that drives the **real running app** (real BLoCs, real Hive persistence, real
Dio) and is easy to extend with new per-feature flow tests.

## Decisions (locked)

- **Framework:** `patrol_finders` (the `$` PatrolTester API) on top of Flutter's
  `integration_test`. See the macOS caveat below for why we use `patrol_finders`
  rather than the full `patrol` native harness.
- **Run target:** macOS desktop — `fvm flutter test integration_test -d macos`
  (launches the real app window).
- **Network:** hermetic in-test localhost `HttpServer` returning canned JSON.
- **Isolation strategy:** approach **A** — a temp Hive profile per run via a tiny
  `di.init()` seam, so E2E never reads or wipes the developer's real data.

## Constraints / caveats

- **Patrol native automation does NOT support macOS desktop** (Patrol's own docs
  call macOS "alpha, no native automation," despite the pub badge listing macOS).
  So the full `patrol test -d macos` harness — `patrol_cli` native runner + an
  Xcode UI-test target — is not a viable path here. Instead we use
  **`patrol_finders`** (the `$` finder API), which runs under `integration_test`
  on the real macOS app with **no native harness**. We keep patrol's test-writing
  ergonomics; we only give up native-OS-dialog automation (already out of scope).
  If full native automation is ever needed, run the same flows on a mobile
  simulator (where patrol native works) — a future, separate target.
- macOS **native file-picker dialogs** (import/export, multipart/binary file
  pick, save-to-file) are **out of scope for v1**. v1 covers in-app flows + the
  mock server only.
- The existing `fvm flutter test` gate is unaffected — it runs `test/`, not
  `integration_test/`.

## Architecture

### 1. Dependencies & setup
- `dev_dependencies`: `patrol_finders: ^3.2.0`, `integration_test` (SDK).
- No `patrol_cli`, no Xcode test target, no `patrol:` pubspec config block —
  none are needed for the finders-over-integration_test path.
- Run: `fvm flutter test integration_test -d macos`.

### 2. Test-isolation seam (only production-code change)
- `di.init({String? storageDirectoryOverride})` — when non-null, use
  `Hive.init(path)` instead of `Hive.initFlutter()`. Default `null` → prod
  behavior unchanged.
- `di.reset()` — `GetIt.reset()` + close all Hive boxes, for between-test
  cleanup. (If a reset helper already exists, extend it; otherwise add it.)
- This single seam is what guarantees the real user profile is never touched.

### 3. Harness (`integration_test/support/`)
- `app_harness.dart` — `bootGetman($, {seed})`: create temp dir →
  `di.init(storageDirectoryOverride: tmp)` → optional box seeding → pump
  `MyApp(initialSettings: ...)` → `pumpAndSettle`. `tearDown` closes boxes,
  `di.reset()`, deletes the temp dir. Teardown must run even on test failure.
- `mock_server.dart` — `startMockServer(routes)`: bind `HttpServer` on
  `localhost:0` (ephemeral port); return `{ baseUrl, close() }`. Routes return
  canned status + JSON.
- `actions.dart` — reusable patrol helpers: `openNewTab`, `enterUrl`,
  `openBodyTab`, `setBodyType`, `tapSend`, response assertions. Add a small
  number of `Key`s to the app where a stable finder is missing (prefer existing
  `ValueKey`s / verbatim UI labels first).

### 4. Example flows (`integration_test/flows/`)
- `smoke_test.dart` — app boots to the tabs view (first run seeds a sample
  `https://httpbin.org/get` request, so the tabs view, not the empty
  placeholder, shows).
- `request_send_test.dart` — URL = mock server → SEND → assert the server got a
  GET on the right path + the `200` STATUS chip renders.
- `json_fold_test.dart` — JSON response renders in the pretty viewer with the
  fold gutter (`DefaultCodeChunkIndicator`) present (ties to the just-shipped
  fold feature).
- `variable_substitution_test.dart` — `{{$timestamp}}` in the URL resolves at
  send time (the mock server receives `/items/<digits>`, not the literal
  token). Uses a **dynamic** built-in so the flow needs no environment-dialog
  driving while still exercising the real substitution pipeline. (A full
  environment-backed `{{var}}` flow that drives the environments dialog is a
  good follow-up.)

Also kept: `pipeline_smoke_test.dart` at the `integration_test/` root — a bare-
widget toolchain guard (no app boot) proving integration_test + patrol_finders +
the macOS build pipeline work.

### 5. Run + docs
- **Runner:** `integration_test/run_macos.sh` runs every flow **one file per
  `flutter test` invocation** — the Flutter *desktop* runner can only host a
  single integration_test file at a time (passing several makes the next fail
  with "Error waiting for a debug connection"). The script loops over the files.
- `integration_test/README.md`: the run command, the temp-profile isolation
  guarantee, the no-`pumpAndSettle`-after-SEND shimmer note, and a "how to add a
  new flow test" recipe.
- `integration_test/analysis_options.yaml`: keeps the full lint baseline for E2E
  code but allows relative imports of `support/` helpers (they live outside
  `lib/`, so `always_use_package_imports` can't apply).

## Data flow

test → `bootGetman` (temp Hive profile) → drive UI via patrol `$` finders →
app dispatches real BLoC events → `NetworkService` (real Dio) hits the
localhost mock server → response renders → assertions on widgets/state.

## Error handling / isolation

- Each test: fresh temp profile + `di.reset()` so no state leaks between tests.
- Mock server on an ephemeral port (no fixed-port collisions); always closed in
  teardown.
- Teardown always runs (even on failure) to avoid leaking temp dirs / open
  boxes / bound sockets.

## Verification

The E2E suite *is* the test. Done = `fvm flutter test integration_test -d macos`
runs green for all v1 flows, AND the existing gate (`fvm flutter analyze`,
`custom_lint`, `bloc_lint`, `dart format`, `fvm flutter test`) stays clean — the
`integration_test/` sources must pass analysis + formatting like the rest.

## Suggested execution order (de-risk the toolchain first)

1. Deps + a trivial pipeline smoke test (pump a bare widget) →
   `fvm flutter test integration_test -d macos` green. (Confirms
   integration_test + patrol_finders + the macOS build pipeline work before
   investing in the harness.)
2. Isolation seam (`di.init` override + `di.reset`).
3. Harness: `app_harness.dart`, `mock_server.dart`, `actions.dart`.
4. The 4 flow tests.
5. `README.md`.

## Out of scope (v1)

- Native file-dialog flows (import/export, file body pick, save-to-file).
- Mobile (iOS/Android) targets.
- CI wiring (run locally pre-publish for now).
