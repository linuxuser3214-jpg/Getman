# E2E coverage backlog

Flows not yet covered by the macOS `patrol_finders` suite (`run_macos.sh`), in
the same evidence-first format as `docs/BACKLOG.md`. The current suite does
**broad happy-path** coverage of each feature; this is the "deep later" list.

Each item: what's missing · why it isn't done yet · a suggested approach.

---

## 1. Command palette (drafted, unregistered)

- **State:** `flows/command_palette_test.dart` exists but is **not** registered
  in `all_flows_test.dart` (so it doesn't run in the suite).
- **Why:** the palette only opens via the Cmd/Ctrl+K shortcut. Simulating the
  combo (`sendKeyDownEvent(metaLeft)` + `keyK`, even with `platform: 'macos'`)
  did not open the palette and surfaced a `No MaterialLocalizations found`
  assertion from a key-message handler rebuild above `MaterialApp`.
- **Suggested:** either (a) add a `@visibleForTesting` way to dispatch
  `CommandPaletteIntent` / open `CommandPalette.show` without the raw key event,
  or (b) get the modifier-key simulation working under
  `IntegrationTestWidgetsFlutterBinding`. Then re-register the flow. The
  filter + result-tap assertions (`palette_search_field`, `palette_result_0`)
  are already written.

## 2. Saved examples (M10)

- **Missing:** capture a response as a saved example under a collection node,
  see it as an inline sub-row, open it as an unlinked tab.
- **Why:** needs the tab to be linked to a node first (the keyed
  `save_as_example_button` only shows when `collectionNodeId != null` **and** a
  response exists). Multi-step; deferred for time.
- **Suggested:** save the request to a node → send → tap
  `save_as_example_button` → enter a name → `SAVE` → expand the node → assert the
  example row → tap it → assert a new (unlinked) tab opened. Anchors exist;
  example rows are keyed `'<nodeId>/<exampleId>'`.

## 3. Native file-dialog flows

- **Missing:** collection/environment import & export, binary & multipart-**file**
  body, response **Save to file**.
- **Why:** `patrol_finders` can't drive native macOS file pickers (Patrol native
  automation is unsupported on macOS desktop).
- **Suggested:** refactor the picker calls behind an injectable seam so tests can
  feed a path without the OS dialog, or run these flows on a mobile simulator
  with Patrol native.

## 4. Drag-and-drop tree reorder

- **Missing:** reordering / re-parenting collection nodes via drag.
- **Why:** `Draggable<String>` / `DragTarget<String>` gestures weren't attempted.
- **Suggested:** `$.tester.drag` / `timedDrag` between node rows (nodes are keyed
  by id), then assert the new order in the tree.

## 5. Code-export reflects edits (and the underlying stale-config bug)

- **State:** `flows/code_gen_test.dart` asserts the cURL snippet for the **seeded**
  request only.
- **Why:** the inline "Generate code" button passes `tab.config` captured at
  url_bar build time; `url_bar`'s `buildWhen` excludes `config.url`, so editing
  the URL then generating code uses the **stale** URL. (Same class of bug fixed
  for `RealtimeButton` this session — it now reads fresh config at press time.)
- **Suggested:** make `CodeExportDialog.show(...)` read the tab's current config
  at press time (mirror the `RealtimeButton` fix), then extend the flow to set
  method + a custom URL and assert they appear in the snippet, and cover the
  other targets (JS fetch / Node axios / Python / Go / Java).

## 6. Environments — secrets & active-env deletion

- **Missing:** marking a variable secret (lock + reveal obscuring) and deleting
  the **active** environment (must fall back to "No Environment").
- **Why:** the create + substitute happy-path is covered; these two are the
  "deep later" slice.
- **Suggested:** in the env editor toggle the row lock (anchored by the variable
  row), assert the value obscures; for deletion, delete the active env from the
  list tile (confirm), reopen the selector, assert "No Environment".

## 7. Settings — network / redirect / mTLS / limits

- **Missing:** history-limit trimming, prettify-large-response rendering,
  connect/send/receive timeouts, follow-redirects + max-redirects, verify-SSL,
  proxy, client certificate (mTLS).
- **Why:** the theme-switch + dark-mode toggles are covered; the rest need
  observable end-to-end effects (and mTLS/proxy need a server that exercises
  them).
- **Suggested:** drive each keyed field, then assert behavior against a mock
  server configured to require/observe the setting.

## 8. Tab management — beyond open/close

- **Missing:** duplicate tab, close-others, close-to-the-right, reorder tabs,
  Cmd+1–9 jump, Ctrl+Tab next/prev, dirty-indicator (`*`) assertions.
- **Suggested:** the right-click tab context menu + keyboard shortcuts; gate the
  shortcut ones on item 1's key-simulation fix.

## 9. Error & edge states

- **Missing:** request timeout, non-2xx rendering, malformed-JSON body, request
  cancel mid-flight (`cancel` key exists), history dedup specifics, every theme
  in light + dark + compact.
- **Suggested:** mock-server responders for each error shape; assert the status
  band / error UI.
