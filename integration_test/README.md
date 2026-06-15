# End-to-end tests (macOS)

These drive the **real Getman app** in a real macOS window — launch it, click,
type, send requests, and assert on what the user would see — so you don't have
to manually click through features before publishing.

## What this is built on

- **`patrol_finders`** — the `$` finder API (`$('text')`, `$(Key(...))`,
  `.tap()`, `.enterText()`, `.waitUntilVisible()`).
- **Flutter `integration_test`** — runs the compiled app on a real device.

> We use `patrol_finders` rather than the full `patrol` native harness because
> Patrol's **native automation does not support macOS desktop** (it's alpha, no
> native support). The finder API is all we need on desktop and runs under
> `integration_test` with no native test target. (If you ever need to automate
> native OS dialogs — file pickers, permissions — run the flows on a mobile
> simulator instead, where patrol native works.)

## Running

Run the whole suite — **builds + launches the app once**, then runs every case:

```bash
bash integration_test/run_macos.sh
```

This runs `all_flows_test.dart`, an aggregator that composes every flow into a
single entry point. One build (~12-15s), then each case takes ~1s.

Run a single flow while developing it (rebuilds, but isolates one flow):

```bash
fvm flutter test integration_test/flows/request_send_test.dart -d macos
```

Toolchain sanity check (no app, just proves the pipeline builds/runs):

```bash
fvm flutter test integration_test/pipeline_smoke_test.dart -d macos
```

**Why an aggregator and not `flutter test integration_test -d macos`?** The
Flutter *desktop* runner can only host one integration_test **file** per
`flutter test` call — passing several together makes the next one fail with
"Error waiting for a debug connection." A single aggregator *file* that imports
the others sidesteps that: it's one file (one build/launch), and all the cases
it pulls in run sequentially in that one app process.

## Isolation (your real data is safe)

Each flow boots the app against a **throwaway temp Hive profile** (via
`di.init(storageDirectoryOverride: ...)`), so a run never reads or wipes your
real saved collections / history / settings. Cleanup (close boxes, reset DI,
delete the temp dir) is registered with `addTearDown`, so it runs even when a
test fails.

## Layout

```
integration_test/
  all_flows_test.dart        # aggregator — runs every flow in one build/launch
  pipeline_smoke_test.dart   # toolchain guard (bare widget, no app)
  run_macos.sh               # runs the aggregator
  support/
    app_harness.dart         # bootGetman($) — boots the real app, isolated
    mock_server.dart         # MockServer — hermetic localhost HTTP server
    actions.dart             # enterUrl / tapSend / sendTo / waitForStatus
  flows/
    smoke_test.dart                 # app boots to the tabs view
    request_send_test.dart          # send a GET → render the 200 response
    json_fold_test.dart             # JSON response shows the fold gutter
    variable_substitution_test.dart # {{$timestamp}} resolves before sending
```

## Adding a new flow

1. Create `flows/<feature>_test.dart`.
2. Register it in `all_flows_test.dart` (import it with a prefix and call its
   `main()`) so the full-suite run picks it up.
3. Start with the skeleton:

   ```dart
   import 'package:flutter_test/flutter_test.dart';
   import 'package:integration_test/integration_test.dart';
   import 'package:patrol_finders/patrol_finders.dart';

   import '../support/actions.dart';
   import '../support/app_harness.dart';
   import '../support/mock_server.dart';

   void main() {
     IntegrationTestWidgetsFlutterBinding.ensureInitialized();

     patrolWidgetTest('describe the user-visible behaviour', ($) async {
       final server = await MockServer.start(json: {'ok': true});
       addTearDown(server.close);

       await bootGetman($);
       // ... drive via `$` and the helpers in support/actions.dart ...
     });
   }
   ```

4. Prefer stable finders: existing `ValueKey`s (`url_field`, `send`, `tabs`,
   `tab_<id>`, …) or verbatim UI labels. If a widget you need has no stable
   anchor, add a `ValueKey` to it in `lib/` (keep these few and intentional).
5. After tapping **SEND**, don't `pumpAndSettle` (the response-pending shimmer
   animates forever) — use `await waitForStatus($, 200)` or
   `.waitUntilVisible()`, which pump without requiring a settle.

## Out of scope (for now)

- Native file-dialog flows (import/export, file body pick, save-to-file) — need
  native automation, which isn't available on macOS desktop.
- Mobile (iOS/Android) targets.
- CI wiring — run locally before publishing.
