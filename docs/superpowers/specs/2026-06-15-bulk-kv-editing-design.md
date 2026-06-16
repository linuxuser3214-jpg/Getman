# Bulk Header / Param Editing — Design

**Date:** 2026-06-15
**Status:** Approved (autonomous design)

## Goal

Let users edit the **Params** and **Headers** tabs as a free-text block
(Postman-style "Bulk Edit") instead of one row at a time. A per-tab toggle
flips the editor between the existing row-by-row `KeyValueListEditor` and a
single multiline text view where each line is `key: value`. Switching either
way preserves the data losslessly (round-trip). Parsing back splits each line
on the **first** `:` and trims both sides; blank lines are ignored.

This is a pure editing-affordance feature — it changes **how** params/headers
are entered, not what they mean or how they are sent. The canonical value
(`List<QueryParamEntity>` for params, `Map<String,String>` for headers) and the
`onChanged` → `UpdateTab` path are completely unchanged.

## Scope

In scope:

- **Params tab** (`ParamsTabView`) — bulk edit over the ordered
  `List<QueryParamEntity>` (URL is the source of truth; see Data flow).
- **Headers tab** (`HeadersTabView`) — bulk edit over the `Map<String,String>`.
- A row ⇄ bulk **toggle** affordance per tab, themed via `context.app*`.
- A new **pure** parse/serialize helper in `lib/core/utils/`.
- A new **reusable atom** in `lib/core/ui/widgets/` hosting the bulk text view.

Out of scope (explicit non-goals, with locked justifications):

- **Environment-variables editor.** The same `KeyValueListEditor` backs env
  vars, but that editor carries the secret lock/reveal affordances
  (`secretKeys` / `onSecretKeysChanged`). A flat `key: value` text block has no
  lossless representation for the secret flag, and round-tripping secrets
  through free text risks leaking a masked value into plain text. **Env vars
  stay row-only and unchanged** — consistent with the hover-tooltip scope
  decision (env editor opts out of variable affordances). The bulk toggle is
  simply not offered there.
- **Disabled / enabled rows.** Verified in code: `QueryParamEntity`
  (`lib/core/domain/entities/query_param_entity.dart`) has only `key` + `value`;
  headers are a plain `Map<String,String>` on `HttpRequestConfigEntity`. Neither
  carries an enabled/disabled flag. **The bulk format is therefore plain
  `key: value` lines with NO disabled syntax** (no leading `#`/`//` comment
  convention). This is locked in; adding a disabled flag is a separate feature
  and would require its own model change + bulk-syntax design.
- **Body / form-data editors.** Multipart/urlencoded form fields
  (`FormDataEditor`) and the raw body are unaffected.
- **Import from clipboard of arbitrary formats** (e.g. cURL `-H`, raw HTTP). Out
  of scope — the cURL paste path in `url_bar.dart` already covers header import.

## Locked decisions

| # | Decision | Justification |
|---|---|---|
| D1 | Bulk format is `key: value`, one pair per line; **no** disabled-row syntax. | Params/headers carry no enabled flag in the model (verified). Inventing a disabled syntax with no backing field would be lossy/misleading. |
| D2 | Parse splits on the **first** `:` only; key = `substring(0, i).trim()`, value = `substring(i+1).trim()`. | A colon is legal inside header/param values (e.g. `Authorization: Bearer x:y`, timestamps). First-colon split matches Postman. |
| D3 | A line with **no** colon → key = the whole trimmed line, value = `''`. (NOT skipped.) | Deterministic and least-surprising: a half-typed `Accept` keeps the user's key while they type the value. Matches the row editor, which lets a key exist with an empty value. |
| D4 | **Blank / whitespace-only lines are ignored** (dropped on parse, not emitted as empty pairs). | Matches the brief and Postman; avoids phantom empty rows when toggling back. |
| D5 | A line whose **key trims to empty** (e.g. `: value`, or `   : x`) is **dropped**. | The existing codecs already drop empty-key rows (`if (key.isNotEmpty)` in both `encode`s). The bulk path must produce the same canonical value or the round-trip diverges. |
| D6 | Serialize (rows → text) emits **one `key: value` line per pair**, in canonical order, value verbatim (no trimming on serialize). Empty-key pairs are skipped (they never reach canonical state anyway). | Mirrors the canonical value exactly so row→bulk→row is identity. Verbatim value preserves intentional trailing/leading spaces a user already committed. |
| D7 | Toggle state (`row` vs `bulk`) is **ephemeral UI state**, held in the `ParamsTabView`/`HeadersTabView` `State` (these become `StatefulWidget`s) — NOT persisted, NOT in any bloc, NOT on the entity. | It is a transient view preference, not request data. Persisting it would bloat `HttpRequestTabModel` (a `@HiveField` change) for zero functional gain. Resets to `row` on tab reload — acceptable and simplest. |
| D8 | The bulk text view commits to the bloc **on every change** via the same `onChanged` the row editor uses, debounced/echo-suppressed by the same mechanism (see Architecture §3). | Keeps a single write path; no "apply" button to forget. Live commit means switching back to rows after bulk edits already reflects the latest text. |
| D9 | Switching **bulk → row** re-parses the current text and commits **once** before flipping, so the row editor seeds from the canonical value (not stale rows). Switching **row → bulk** serializes the current canonical value into the text view. | Guarantees the toggle is lossless in both directions regardless of un-committed keystrokes. |
| D10 | Params bulk edits still flow through `copyWith(params:)`, which rewrites the URL query. **The URL remains the single source of truth for params.** | `HttpRequestConfigEntity.params` is derived from the URL; the existing `ParamsTabView.onChanged` already does this. Bulk reuses it verbatim. |

## Architecture

All pieces are theme-driven (no hardcoded colors/sizes/radii/weights — pulled
from `context.app*`) and live where existing patterns dictate. No new
dependencies.

### 1. Parse / serialize helper (`lib/core/utils/`)

A pure-Dart utility — no Flutter, no bloc — so it is unit-testable in isolation
and reusable by both tabs.

**File:** `lib/core/utils/bulk_kv_codec.dart`

```
class BulkKvCodec {
  BulkKvCodec._();

  /// Rows -> text block. One `key: value` line per pair, canonical order,
  /// value verbatim. Empty-key pairs skipped.
  static String serialize(List<(String, String)> rows);

  /// Text block -> rows. Split each line on the FIRST ':'.
  ///   - blank / whitespace-only line  -> dropped (D4)
  ///   - no colon                      -> (trimmedLine, '')           (D3)
  ///   - colon present                 -> (key.trim(), value.trim())  (D2)
  ///   - empty key after trim          -> dropped                     (D5)
  static List<(String, String)> parse(String text);
}
```

It deals only in the editor's row currency `List<(String, String)>` — the exact
type `KeyValueListEditor.decode`/`encode` already speak. It does **not** know
about `QueryParamEntity` or `Map`; the existing per-tab `encode` codec converts
rows → canonical value as it does today. This keeps the helper trivially pure
and keeps the params/headers shape difference inside the tab views where it
already lives.

### 2. Bulk text view (presentation, reusable atom)

**File:** `lib/core/ui/widgets/bulk_kv_editor.dart`

```
class BulkKvEditor extends StatefulWidget {
  const BulkKvEditor({
    required this.initialText,   // serialized canonical value at open time
    required this.onChanged,     // ValueChanged<String> raw text -> owner
    super.key,
    this.fieldPrefix,            // E2E ValueKey anchor, mirrors KeyValueListEditor
  });
}
```

- A single multiline `TextField` (`maxLines: null`, `expands: true`,
  `keyboardType: TextInputType.multiline`), monospace-friendly: text style uses
  `context.appTypography` (`codeFontFamily` + `bodyWeight`) and
  `context.appLayout.fontSizeCode`; the field decoration radius is
  `context.appShape.inputRadius`; padding from `context.appLayout.inputPadding`.
  Hint text (e.g. `Key: Value\nKey: Value`) pulled from a constant, styled via
  the theme.
- Owns its own `TextEditingController` seeded from `initialText` in
  `initState`. **Echo-suppression mirror of `KeyValueListEditor`:** it only
  re-seeds the controller in `didUpdateWidget` when `widget.initialText`
  changes AND differs from the controller's current text (guarded compare), so
  the BLoC round-trip echo does not reset the cursor mid-type. This is the same
  `_lastEmitted`-style pitfall the row editor avoids; here it is one controller,
  one string compare.
- `onChanged` reports the **raw text** upward. Parsing to rows happens in the
  owning tab view (so the existing `encode` codec runs there). The atom stays
  format-agnostic about the canonical type.
- When `fieldPrefix` is set, the `TextField` gets
  `ValueKey('<prefix>_bulk')` for E2E targeting (consistent with
  `KeyValueListEditor`'s `fieldPrefix` convention).

The atom is generic (no params/headers knowledge), so it qualifies for
`lib/core/ui/widgets/` per the atomic-design mandate.

### 3. The toggle + view switch (the tab views)

`ParamsTabView` and `HeadersTabView` (`request_editor_tabs.dart`) become
`StatefulWidget`s. They keep their existing `BlocBuilder` + `_VariableContextBuilder`
wrapping; the inner builder now branches on a `bool _bulk` field:

- **Toggle affordance:** a small header `Row` above the editor body with the
  current mode and a button to switch. Rendered with
  `context.appDecoration.wrapInteractive(...)` around an `IconButton`/text
  button, themed via `context.appTypography` (label) +
  `context.appPalette` (icon/active color) + `context.appShape.buttonRadius`.
  Icon: `Icons.view_list_outlined` (→ shows when in bulk, switches to rows) /
  `Icons.notes_outlined` (→ shows when in rows, switches to bulk). Tooltip
  copy: `'Bulk edit'` / `'Edit as rows'`. **No new ThemeExtension field is
  required** — all sizes/colors/radii/weights already exist on the current
  extensions (`appLayout.iconSize`, `appLayout.tabSpacing`, etc.). If a label
  string needs to read in each theme's voice it can later move to `AppCopy`;
  for v1 the two fixed labels are acceptable plain strings (UI labels, not
  themeable surfaces).
- **Row mode (`_bulk == false`):** renders the existing
  `KeyValueListEditor<...>` exactly as today (params: `List<QueryParamEntity>`,
  headers: `Map<String,String>`), passing the same `decode`/`encode`/`equals`/
  `onChanged`/`variableContext`/`fieldPrefix`.
- **Bulk mode (`_bulk == true`):** renders `BulkKvEditor` with
  `initialText = BulkKvCodec.serialize(decode(items))` and
  `onChanged: (text) => onChanged(encode(BulkKvCodec.parse(text)))`.
  `decode`/`encode` are the **same closures** already defined in the tab view —
  so bulk and row paths produce identical canonical values and reuse the one
  `UpdateTab` dispatch.
- **Flipping the toggle (D9):**
  - row → bulk: just set `_bulk = true` and rebuild; `BulkKvEditor` seeds from
    the current canonical value via `serialize(decode(items))`.
  - bulk → row: set `_bulk = false` and rebuild; the row editor seeds from the
    current canonical value (already committed on each keystroke per D8), so no
    explicit re-commit is needed — but the switch is still safe because the last
    `onChanged` ran on the most recent text.

  Because every bulk keystroke already commits through `onChanged` (D8), the
  canonical value the bloc holds is always current; the toggle never has to
  reconcile "uncommitted" text. (This is the simplest correct design and avoids
  an apply button.)
- **Variable highlighting in bulk mode:** out of scope for v1. The bulk
  `TextField` is plain text (no `{{var}}` token coloring / hover popover). The
  row editor keeps its highlighting via `variableContext`. Rationale: a
  multiline value-with-key text block has no per-value span model wired today,
  and the brief scopes this feature to editing affordance, not highlighting.
  Locked as a non-goal; revisit if requested.

### 4. Why no bloc / domain changes

- No entity field changes (toggle is ephemeral UI state, D7).
- No new bloc events: bulk commits via the existing `UpdateTab` through the
  same `onChanged`. `TabsBloc` is untouched.
- No new repository or use case. The domain layer is not involved.
- Two-bloc coordination is **not** introduced; this feature reads/writes only
  `TabsBloc` (via the existing `context.read<TabsBloc>()` already inside the tab
  views). The `_VariableContextBuilder` (Settings + Environments blocs) is only
  consulted for the row editor's highlighting, exactly as today.

## Data flow

```
[ row mode ]
KeyValueListEditor rows --encode--> canonical (List<QueryParamEntity> / Map)
   --onChanged--> UpdateTab(config.copyWith(params|headers)) --> TabsBloc

[ bulk mode ]
TextField text --BulkKvCodec.parse--> rows --encode(same closure)-->
   canonical --onChanged(same closure)--> UpdateTab --> TabsBloc

[ toggle row->bulk ]   canonical --decode--> rows --BulkKvCodec.serialize--> text
[ toggle bulk->row ]   (canonical already current) --decode--> rows -> KeyValueListEditor

[ params specifically ]
canonical List<QueryParamEntity> --copyWith(params:)--> URL query rewrite
   (URL stays single source of truth, unchanged from today)
```

Round-trip identity guarantee:
`parse(serialize(rows)) == rows` for any canonical `rows` (empty-key rows never
exist in canonical state; values are emitted verbatim and re-trimmed only when
they contain no surrounding whitespace — see edge cases).

## Error handling / edge cases

- **Value containing a colon** (`Authorization: Bearer a:b`) → key
  `Authorization`, value `Bearer a:b` (first-colon split, D2). Round-trips.
- **No colon** (`Accept`) → key `Accept`, value `''` (D3).
- **Empty key** (`: value`, `=foo` with leading colon, or `   :x`) → dropped
  (D5), matching the existing `encode` empty-key filter.
- **Blank lines / trailing newline** → ignored (D4); a trailing newline from
  the text field does not create a phantom pair.
- **Duplicate keys (params):** preserved in order — `QueryParamEntity` list
  allows duplicates and the bulk path keeps line order, so two `tag: a` /
  `tag: b` lines produce two params, matching the row editor.
- **Duplicate keys (headers):** last-write-wins, because the headers `encode` is
  a map literal (`{for ... key: value}`) — identical to row-mode behavior today.
- **Value with leading/trailing spaces the user wants:** trimmed on parse (D2)
  — locked tradeoff. Postman trims too; a user needing literal surrounding
  whitespace in a header value is vanishingly rare and the row editor doesn't
  specially preserve it either once it round-trips through the URL/map.
- **`{{var}}` tokens in bulk text:** treated as ordinary characters (no special
  parsing); they survive verbatim into the value and resolve at send time as
  usual. Colons are not valid inside the variable token grammar, so a
  `{{ name }}` value never trips the first-colon split.
- **Toggling with the field focused mid-type:** the last `onChanged` already
  committed the canonical value (D8), so the switch shows current data; no data
  loss.
- **Echo write while typing in bulk mode:** suppressed by the `initialText`
  guarded compare in `BulkKvEditor.didUpdateWidget` (§2) — cursor not reset.
- **Tab reload / app restart:** `_bulk` resets to `row` (D7). No persistence
  expectation set in the UI.

## Testing

Pure-logic unit tests (`test/core/utils/bulk_kv_codec_test.dart`):

- `serialize`: rows → text, canonical order, value verbatim, empty-key rows
  skipped, empty list → `''`.
- `parse`: first-colon split; no-colon → empty value; blank/whitespace lines
  dropped; empty-key lines dropped; value-with-colon preserved; trailing
  newline ignored; duplicate keys preserved in order.
- **Round-trip property:** `parse(serialize(rows)) == rows` for representative
  canonical inputs (incl. duplicates, empty values, colon-in-value).

Widget tests (`test/core/ui/widgets/bulk_kv_editor_test.dart` and an addition to
`test/features/tabs/.../request_editor_tabs_test.dart` or a new
`bulk_kv_toggle_test.dart`):

- `BulkKvEditor` seeds from `initialText`, reports raw text on change, and does
  **not** reset the cursor on an echo (`didUpdateWidget` with equal text).
- **Toggle round-trip:** start in row mode with known params/headers, switch to
  bulk → text shows the serialized block; edit the text → switch back to rows →
  rows reflect the parsed canonical value; assert no data lost (a row added in
  bulk appears as a row; a malformed line behaves per D3/D5).
- **Regression:** with the toggle in row mode, existing `KeyValueListEditor`
  behavior and the existing `key_value_list_editor_test.dart` stay green
  (the row path is unchanged).
- Env-vars editor is unaffected: no toggle is rendered there (it never receives
  the bulk affordance).

Full done-bar (CLAUDE.md §5): `fvm flutter analyze` (VGA), `fvm dart run
custom_lint`, `fvm dart run bloc_tools:bloc lint lib`, `fvm dart format`
cleanliness, and `fvm flutter test` all green. Imports are `package:getman/...`
throughout; no `sl`/`GetIt` in widgets.

## Wiki

Per the "Keep the wiki in sync" mandate (CLAUDE.md §7): this adds a
user-visible capability (a Bulk Edit toggle on Params and Headers). Update the
**Requests** page (the one documenting the PARAMS / HEADERS / BODY tabs) in the
`Getman.wiki.git` repo: describe the row ⇄ bulk toggle, the `key: value`
line format, the first-colon split rule, that blank lines are ignored, that
there is no disabled-row syntax, and that the env-variables editor is
intentionally row-only. Use verbatim UI labels (`Bulk edit` / `Edit as rows`).
No new page needed; no `_Sidebar.md` change.
