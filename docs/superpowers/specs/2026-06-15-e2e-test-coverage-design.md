# E2E Test Coverage Expansion — Design

**Date:** 2026-06-15
**Goal:** Replace manual click-through QA with automated `patrol_finders` E2E flows
covering the *usage* of every Getman feature. Driven by
`bash integration_test/run_macos.sh`.

## Decisions (from brainstorming)

- **Coverage style:** *Broad now, deep later.* One happy-path user journey per
  feature this session; deeper edge cases and unreachable flows go to a backlog.
- **Test anchors:** Add intentional, well-named `ValueKey`s to `lib/` wherever a
  finder would otherwise be fragile. Today only 4 exist (`url_field`, `send`,
  `tabs`, `cancel`).
- **Infra-heavy features:** Build mock WebSocket + SSE infra and cover realtime.
  Explicitly cover chaining **rules** (assertions + extraction) and the response
  **Tests** view.
- **Native file dialogs** (import/export, file & multipart-file body,
  save-to-file): out of scope this session — patrol can't drive native macOS
  dialogs. → Backlog.
- **Organization:** Hybrid (Option C) — one `flows/<feature>_test.dart` per
  feature, plus a few natural cross-feature journeys (e.g. send → history →
  re-send). Matches the existing convention; one build/launch via the
  `all_flows_test.dart` aggregator.

## Existing infrastructure (reused, not rebuilt)

- `support/app_harness.dart` — `bootGetman($)`: boots the real app against a
  throwaway temp Hive profile; teardown resets DI + deletes the temp dir.
- `support/mock_server.dart` — hermetic localhost HTTP server; records requests;
  canned or custom (`MockResponder`) responses.
- `support/actions.dart` — `enterUrl`, `tapSend`, `sendTo`, `waitForStatus`.
- `all_flows_test.dart` — aggregator; every flow's `main()` is registered here.

## New infrastructure

- `support/mock_ws_server.dart` — hermetic WebSocket echo server (bind ephemeral
  loopback port; upgrade `HttpRequest`; echo frames) **and** an SSE responder
  helper (a `MockResponder` that writes `text/event-stream` chunks over the
  existing `MockServer`).
- `support/actions.dart` additions — `newTab`, `setMethod`, `openRequestTab`,
  `openResponseTab`, `addKeyValueRow`, `saveToCollection`, `openCommandPalette`,
  and similar small wrappers over stable anchors.

## ValueKeys to add to `lib/` (as each flow needs them)

Request/response tab-strip items (PARAMS/HEADERS/BODY/AUTH/RULES,
BODY/HEADERS/COOKIES/TESTS), `KeyValueListEditor` row key/value fields + add
button, body-type selector + raw editor, auth type selector + token/user/pass/
api-key fields, environment dialog (name field, add-variable, secret lock,
active-env selector), command palette (search field + result rows), rules editor
(add-assertion/add-extraction + their fields), settings toggles
(theme/dark/compact/prettify), and tab close buttons. Names kept stable and
descriptive.

## This-session flow inventory (happy-path each)

| Flow file | Covers |
|---|---|
| `tabs_test.dart` | new tab (Cmd+N), close (Cmd+W), switch active, duplicate, cURL paste → method/url/headers/body, cancel in-flight, dirty indicator |
| `request_config_test.dart` | set method GET→POST, add a query param (reflects in URL + sent request), add a header (sent), raw JSON body sent, urlencoded body sent |
| `history_test.dart` | send → entry appears in history; open/re-send from history (cross-feature journey) |
| `collections_test.dart` | save request to collection, create folder, rename, delete (confirm), favorite, edit description, open saved request in tab |
| `saved_examples_test.dart` | save response as example → appears under node → open as unlinked tab |
| `environments_test.dart` | create env + add variable, set active, `{{var}}` resolves in send, secret variable (lock + obscured), delete active env → falls back to No Environment |
| `chaining_rules_test.dart` | add passing assertion (status == 200) → Tests view shows pass; add failing assertion → shows fail; extraction rule captures a value → written back to active env |
| `cookies_test.dart` | server sets cookie → response Cookies view shows it; jar persists; manager UI lists + deletes it; next send includes stored cookie |
| `realtime_ws_test.dart` | WebSocket connect → send → receive echo → disconnect |
| `realtime_sse_test.dart` | SSE connect → receive streamed events |
| `command_palette_test.dart` | Cmd+K opens → fuzzy search a saved request → Enter opens it |
| `auth_test.dart` | bearer token → `Authorization: Bearer …` sent; basic auth → header sent; api-key → header/query sent |
| `code_gen_test.dart` | open code export dialog → cURL target → snippet contains method + url |
| `settings_test.dart` | switch theme (brutalist→editorial→rpg) takes effect; toggle dark mode; toggle compact mode |
| `response_views_test.dart` | pretty/raw body toggle, headers view, metadata (status/time/size) |

Cross-feature journeys live where most natural (history re-send, command-palette
jump to a saved request).

## Backlog (`integration_test/BACKLOG.md`)

Everything not reached this session, in the `docs/BACKLOG.md` format (path +
evidence + suggested approach + working agreement):

- Native-dialog flows: collection/env import & export, file & multipart-file
  body, response save-to-file.
- Drag-and-drop tree reorder.
- Settings: history-limit trimming, prettify-large-responses rendering,
  network/redirect/mTLS fields.
- Deeper edges: history dedup specifics, request cancel races, every code-gen
  target (JS/Node/Python/Go/Java), every theme in light+dark+compact, error
  states (timeouts, non-2xx, malformed JSON), `_PrettyRawToggle` large-body
  cache, response copy.

## Verification bar

`bash integration_test/run_macos.sh` is green (whole suite, one build/launch).
The project static-analysis stack stays clean for any `lib/` ValueKey additions:
`fvm flutter analyze`, `fvm dart run custom_lint`,
`fvm dart run bloc_tools:bloc lint lib`, and `fvm dart format`.
