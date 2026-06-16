# Response Diff — Design

**Date:** 2026-06-15
**Status:** Approved (autonomous design)

## Goal

Let the user compare the **current tab's response** against a **chosen target
response** and see what changed: a unified, per-line-colored diff of the
pretty-printed bodies plus a compact summary of the status-code and header
deltas. The target is picked from two sources that the app already stores:

1. **Saved examples** of the tab's linked collection node
   (`SavedExampleEntity.config` carries a response snapshot), and
2. **Recent history entries** whose `method` + `url` match the current request.

This turns "did this endpoint's response change since I last saved it?" /
"why does this run differ from the last one?" into a one-click answer, reusing
the response value object and the prettify pipeline already in the codebase.

## Scope

In scope:

- A **Compare** action in the response pane (`ResponseBodyView`), mirroring the
  existing Copy / Save-to-file / Save-as-example `IconButton`s. Shown only when
  a response exists on the current tab.
- A **target-picker** dialog listing the tab's saved examples and recent
  matching history entries; selecting one opens the diff view.
- A **diff view** dialog: a unified line diff of the two pretty-printed bodies,
  plus a status/header delta summary header naming both sources.
- A **pure-Dart LCS line-diff** util and a **pure-Dart diff-model builder** that
  maps two `HttpResponseEntity` into a rendered diff model. Both independently
  unit-testable.
- New `AppPalette` fields for added/removed line colors (added to **all four**
  registered themes).

Out of scope (explicit non-goals, with rationale):

- **Char-level / word-level (intra-line) diffing.** Locked to line-level on the
  pretty-printed body (see Locked Decisions). Char/word highlighting is a noted
  follow-up.
- **Three-way / N-way compare.** Always exactly two responses (current vs one
  target).
- **Diffing arbitrary requests** (e.g. two history entries with neither being
  the current tab). The "left" side is always the current tab's live response.
- **Editing / re-sending from the diff view.** Read-only. (Opening a target as
  its own tab is already covered by saved-examples behavior; not duplicated
  here.)
- **Persisting diffs.** The diff is computed on demand from in-memory state;
  nothing new is written to Hive. **No new Hive typeId** (next free stays 11).
- **Semantic JSON diffing** (key-aware, order-insensitive). Bodies are diffed as
  pretty-printed text; this is deterministic and matches what the user sees in
  the body viewer.

## Locked Decisions

1. **Diff algorithm = a small in-repo LCS line-diff. No new dependency.**
   The surgical-dependency mandate (CLAUDE.md §7) forbids pulling
   `diff_match_patch` for a line-diff we can write in ~60 lines. A standard
   Hirschberg-free LCS dynamic-programming table over the two line lists is
   ample for response bodies (line counts, not characters, drive the table) and
   keeps the logic pure, testable, and dependency-free. Lives in
   `lib/core/utils/line_diff.dart`.

2. **Granularity = line-level on the pretty-printed bodies.** We prettify both
   bodies via the existing `JsonUtils.prettify` (so JSON normalizes to the same
   4-space indentation the body viewer uses) and diff line lists. Char/word-level
   is deferred. Justification: line-level is the cheapest correct unit, matches
   the on-screen rendering, and avoids the O(n·m) blowup of char-level on large
   bodies.

3. **Compare sources = saved examples of the linked node + matching history.**
   Both are already in memory (`CollectionsBloc`/`HistoryBloc` state). Matching
   history is filtered by `method` + `url` equality (case-sensitive method,
   exact URL — the templated, unresolved URL as stored). No network calls.

4. **Two blocs are read at the widget layer; never bloc→bloc.** The entry-point
   widget reads `TabsBloc` (current response), `CollectionsBloc` (examples), and
   `HistoryBloc` (matching entries) via `context.read<…>()`, mirroring
   `EnvironmentsDialog._deleteEnvironment` (CLAUDE.md §4.10). No new bloc, no new
   events — the feature is read-only over existing state.

5. **Large bodies respect the existing thresholds.** The diff-model builder
   short-circuits when either body exceeds `kLargeResponseViewerChars`
   (512 KiB) — it does **not** prettify or diff multi-MB strings on the UI
   isolate. Instead it returns a `tooLarge` diff model and the view shows a
   "responses too large to diff inline" banner with the status/header summary
   still rendered. The over-1-MB `kResponseBodyTooLargePlaceholder` sentinel is
   treated as a single opaque line (never re-parsed). Justification: identical
   reasoning to `_ResponseBodyView`'s large-mode guard.

6. **UI = two `ResponsiveDialogScaffold`s** (target-picker, then diff view),
   not a new response sub-tab. Keeps the response pane's 4-tab layout
   untouched and reuses the existing responsive dialog/full-screen chrome.

## Architecture

Five isolated units, each independently testable. Pure logic in
`lib/core/utils/`; the reusable diff/picker widgets in `lib/core/ui/widgets/`
(cross-feature atoms); the entry-point wiring in the tabs feature.

### Unit 1 — Pure line-diff util (`lib/core/utils/line_diff.dart`)

Pure Dart, no Flutter, no equatable dependency required (plain value types are
fine, but we use `Equatable` for cheap test assertions — equatable is allowed in
core utils).

```
enum DiffLineKind { equal, added, removed }

class DiffLine extends Equatable {
  const DiffLine(this.kind, this.text);
  final DiffLineKind kind;   // equal | added | removed
  final String text;         // the line content (no trailing newline)
  @override
  List<Object?> get props => [kind, text];
}

class LineDiff {
  /// LCS-based unified line diff. `left` lines that are absent from the LCS are
  /// `removed`; `right` lines absent from the LCS are `added`; LCS lines are
  /// `equal`. Output is in unified order (removed before added within a hunk).
  static List<DiffLine> diff(List<String> left, List<String> right);

  /// Convenience: splits on `\n` (keeping no trailing empty element beyond the
  /// real content) and calls [diff].
  static List<DiffLine> diffText(String left, String right);
}
```

Algorithm: classic LCS DP table (`O(n·m)` time, `O(n·m)` space) over line lists,
then a backtrack emitting `equal` for matches, `removed` for left-only, `added`
for right-only. Deterministic ordering: within a changed hunk, all `removed`
lines precede `added` lines (standard unified-diff convention).

### Unit 2 — Diff-model builder (`lib/core/utils/response_diff_builder.dart`)

Pure Dart. Maps two `HttpResponseEntity` into a fully-rendered, render-agnostic
model. **This is where prettify + the large-body guard live**, so the widget
layer stays dumb.

```
class HeaderDelta extends Equatable {
  const HeaderDelta({required this.key, required this.left, required this.right});
  final String key;
  final String? left;   // null = absent on the left (added)
  final String? right;  // null = absent on the right (removed)
  bool get isAdded   => left == null && right != null;
  bool get isRemoved => left != null && right == null;
  bool get isChanged => left != null && right != null && left != right;
  // props: [key, left, right]
}

class ResponseDiffModel extends Equatable {
  const ResponseDiffModel({
    required this.leftStatus,
    required this.rightStatus,
    required this.bodyLines,        // empty when tooLarge or identical-empty
    required this.headerDeltas,     // changed/added/removed header keys only
    required this.bodiesIdentical,  // true when no add/remove lines
    required this.tooLarge,         // true when a body exceeded the threshold
  });
  // ...props of all fields
}

class ResponseDiffBuilder {
  /// `left` = current tab response, `right` = chosen target.
  /// Async because it awaits `JsonUtils.prettify` (which may hop an isolate).
  static Future<ResponseDiffModel> build(
    HttpResponseEntity left,
    HttpResponseEntity right,
  );
}
```

Builder steps:
1. **Status:** copy both `statusCode`s into the model.
2. **Headers:** compute `headerDeltas` over the union of keys
   (case-insensitive key comparison — HTTP header names are case-insensitive;
   compare via lowercased keys, surface the left's original casing, falling back
   to the right's). Only keys that differ produce a `HeaderDelta`.
3. **Large guard:** if either `left.body.length` or `right.body.length`
   exceeds `kLargeResponseViewerChars`, return with `tooLarge: true`,
   `bodyLines: []` (status + header summary still populated). Never prettify.
4. **Body:** else prettify both bodies (`JsonUtils.prettify`), split into lines,
   run `LineDiff.diff`, store as `bodyLines`. `bodiesIdentical` is
   `bodyLines.every((l) => l.kind == DiffLineKind.equal)`.

### Unit 3 — Diff view widget (`lib/core/ui/widgets/response_diff_view.dart`)

A `StatelessWidget` (or thin `StatefulWidget` if it needs the `Future` from the
builder — see Data flow) that takes a resolved `ResponseDiffModel` plus the two
source **labels** (e.g. `"This response"` / `"Example: 200 · 14:03"`) and
renders inside a `ResponsiveDialogScaffold`:

- **Summary header** (top): two source labels; a status row showing
  `leftStatus → rightStatus` using `context.appPalette.statusAccent(code)` for
  each badge; and a header-delta count (`"3 headers changed"`), expandable to a
  small list of `HeaderDelta`s (added/removed/changed), keyed off the same
  add/remove palette colors.
- **Body diff** (scrollable, monospace): one row per `DiffLine`. Equal lines use
  `theme.colorScheme.onSurface` on `context.appPalette.codeBackground`; `added`
  lines tint with the **new** `context.appPalette.diffAddedBackground` +
  `diffAddedForeground`; `removed` lines with `diffRemovedBackground` +
  `diffRemovedForeground`. A leading gutter glyph (`+` / `-` / ` `) is rendered
  in the same per-line color. Font from `context.appTypography.codeFontFamily`,
  size `context.appLayout.fontSizeCode`.
- **`bodiesIdentical`** → a centered "Bodies are identical" note instead of the
  line list (header/status summary still shown above).
- **`tooLarge`** → a banner ("Responses too large to diff inline (over
  512 KB)") in place of the body list; summary still shown.

All sizing/padding via `context.appLayout`; all weights via
`context.appTypography`; gutter/row colors via `context.appPalette`. **No literal
colors/sizes/radii.**

### Unit 4 — Target-picker dialog (`lib/core/ui/widgets/compare_target_picker.dart`)

A `ResponsiveDialogScaffold` listing selectable targets in two labeled sections.
It is **passed** its data (does not read blocs itself), so it stays a pure
presentational atom and is widget-testable without bloc scaffolding:

```
enum CompareTargetSource { example, history }

class CompareTarget extends Equatable {
  const CompareTarget({
    required this.id,
    required this.source,
    required this.label,      // "200 · 14:03" (example) or "GET /users · 200" (history)
    required this.subtitle,   // captured-at / relative time / status
    required this.response,   // the HttpResponseEntity to diff against
  });
  // ...
}

/// Returns the chosen target via the dialog's Navigator.pop result (a
/// `CompareTarget?`). null = cancelled.
class CompareTargetPicker extends StatelessWidget {
  const CompareTargetPicker({required this.examples, required this.history, ...});
  final List<CompareTarget> examples;  // section 1
  final List<CompareTarget> history;   // section 2
}
```

- **Sections:** "SAVED EXAMPLES" and "RECENT (this request)". Each row is a
  `wrapInteractive`-wrapped tile showing label + subtitle + a status badge
  (`statusAccent`). Tapping pops with that `CompareTarget`.
- **Empty state:** if **both** lists are empty the picker is never opened (the
  Compare button is disabled — see Unit 5). If one section is empty it renders a
  muted "None" placeholder; the other still works.

### Unit 5 — Entry-point wiring (`response_body_view.dart`)

A `_compareButton(context)` `IconButton` (icon `Icons.difference_outlined`,
tooltip `"Compare response"`, `ValueKey('compare_response_button')`) added to
the action `Row` in both `_buildSmallMode` and `_buildLargeMode`, beside Copy /
Save / Save-as-example.

Its `onPressed` (`_compareResponse`) does the **widget-layer coordination**:

1. Read the current tab + response: `context.read<TabsBloc>().state.tabs.byId(widget.tabId)`.
   Bail (return) if `response == null`.
2. Build the example targets: if `tab.collectionNodeId != null`, look up the
   node via `CollectionsTreeHelper.findNode(context.read<CollectionsBloc>().state.collections, tab.collectionNodeId!)`
   and map each `node.examples` whose `config` has a non-null `statusCode` into a
   `CompareTarget` (source `example`), converting the example's response columns
   (`statusCode`/`responseBody`/`responseHeaders`/`durationMs` on the
   `HttpRequestConfigEntity`) into an `HttpResponseEntity`.
3. Build the history targets: from `context.read<HistoryBloc>().state.history`,
   filter to entries with the **same `method` + `url`** as `tab.config` **and** a
   non-null `statusCode`, take the newest N (cap, e.g. 20), map each into a
   `CompareTarget` (source `history`).
4. The Compare button is **disabled** (greyed, no-op) when both lists would be
   empty — computed via a `BlocBuilder` over `TabsBloc`/`CollectionsBloc`/
   `HistoryBloc` like the existing `_saveAsExampleButton` `buildWhen` gate, or
   simply opened-then-shows-empty if cheaper; the locked behavior is **disable**.
5. `showDialog<CompareTarget>` → `CompareTargetPicker`. If a target is returned,
   `await ResponseDiffBuilder.build(currentResponse, target.response)` then
   `showDialog` → `ResponseDiffView`. Guard with `if (!context.mounted) return;`
   after each await (VGA `use_build_context_synchronously`).

A `CompareTarget` ↔ `HttpResponseEntity` mapping helper for examples/history
lives next to the builder (e.g. `responseFromConfig(HttpRequestConfigEntity)` in
`response_diff_builder.dart` — pure, testable) so the widget does no
reconstruction logic inline.

## Data flow

```
[Compare button in ResponseBodyView]
   │ reads (widget layer, never bloc→bloc):
   │   TabsBloc.state        → current HttpResponseEntity + tab.config + collectionNodeId
   │   CollectionsBloc.state → node.examples (via CollectionsTreeHelper.findNode)
   │   HistoryBloc.state     → entries matching method+url
   ▼
[map → List<CompareTarget> (examples) + List<CompareTarget> (history)]
   │ showDialog<CompareTarget>
   ▼
[CompareTargetPicker]  ── user picks ──▶ CompareTarget (or null = cancel)
   │
   ▼
[ResponseDiffBuilder.build(currentResponse, target.response)]  (async; prettify + LCS)
   │  ├─ LineDiff.diff(prettyLeftLines, prettyRightLines)
   │  └─ header/status deltas + large-body guard
   ▼
[ResponseDiffModel] ── showDialog ──▶ [ResponseDiffView]  (renders summary + per-line diff)
```

Nothing is dispatched to any bloc; nothing is persisted. The feature is a pure
read + compute over existing in-memory state.

## Error handling / edge cases

- **No response on the current tab:** Compare button hidden (same gate as
  Save-as-example: requires `response != null`).
- **No targets at all** (no examples, no matching history): Compare button
  **disabled** with tooltip `"No saved examples or matching history to compare"`.
- **Identical bodies:** `ResponseDiffModel.bodiesIdentical == true`; view shows
  "Bodies are identical" (status/header summary still rendered, which may itself
  show deltas even when bodies match).
- **Identical responses entirely:** identical bodies + zero header deltas + same
  status → view shows "These responses are identical."
- **Huge body on either side** (> `kLargeResponseViewerChars`): builder sets
  `tooLarge`; no prettify, no LCS; view shows the too-large banner + summary.
  Respects the same threshold as `_ResponseBodyView`.
- **Over-1-MB placeholder body:** treated as a single opaque line; it never
  re-parses as JSON (prettify already passes it through verbatim). If both sides
  are the placeholder, `bodiesIdentical` is true.
- **Non-JSON bodies** (HTML/text): `JsonUtils.prettify` returns them verbatim;
  the line diff still works on raw text. No special-casing needed.
- **History entry with a templated (`{{var}}`) URL:** matching is on the stored
  templated URL (CLAUDE.md: history keeps the unresolved config), so a target
  matches the tab's templated URL — consistent and predictable.
- **Example with no captured response** (`config.statusCode == null`): excluded
  from the example list (filtered in step 2).
- **Context unmounted across awaits:** every `showDialog`/`build` await is
  followed by `if (!context.mounted) return;`.
- **Header key casing:** compared case-insensitively (HTTP semantics) so
  `Content-Type` vs `content-type` is not a false delta.

## Theme additions (AppPalette)

Add **four** fields to `AppPalette`
(`lib/core/theme/extensions/app_palette.dart`) — wired through the constructor,
`copyWith`, and `lerp` — and provide values in **all four** theme builders
(`brutalist`, `dracula`, `editorial`, `rpg`; brutalist/dracula define theirs in
their `*_palette.dart` helpers). Never hardcode green/red in widgets.

```
final Color diffAddedBackground;     // subtle add tint behind a line
final Color diffAddedForeground;     // add line text + '+' gutter
final Color diffRemovedBackground;   // subtle remove tint behind a line
final Color diffRemovedForeground;   // remove line text + '-' gutter
```

Per-theme guidance (each theme owns its exact hue, kept on-brand and
WCAG-legible against `codeBackground`): brutalist — saturated green/red on a
pale tint; editorial — muted sage/terracotta; rpg ("Arcane Quest") — its
existing success/danger accents; dracula — its palette's green (`#50fa7b`-ish)
and red/pink. Reuse each theme's existing `statusSuccess`/`statusError` family
as the foreground where it reads well; the backgrounds are low-alpha tints of
the same. `lerp` interpolates all four with `Color.lerp(...)!` exactly like the
existing fields.

(No `AppLayout`/`AppShape`/`AppTypography` additions are needed — row padding,
code font, and dialog radius already exist.)

## Testing

Unit (pure, fast, no Flutter):

- **`line_diff_test.dart`** — identical inputs → all `equal`; pure insertion;
  pure deletion; replacement (removed-then-added ordering); empty vs non-empty;
  interleaved changes; `diffText` newline splitting (incl. trailing newline).
- **`response_diff_builder_test.dart`** — status copied through; header deltas
  (added/removed/changed/case-insensitive-no-false-delta); `bodiesIdentical`
  for equal bodies; JSON bodies prettified before diffing (key-reordered JSON
  still diffs by pretty text — documents the line-level limitation);
  `tooLarge` set when either body exceeds `kLargeResponseViewerChars` (and that
  it does **not** prettify in that case); `responseFromConfig` reconstructs an
  `HttpResponseEntity` from an example/history config.

Widget:

- **`compare_target_picker_test.dart`** — renders both sections; empty section
  shows "None"; tapping a row pops the right `CompareTarget`; cancel pops null.
- **`response_diff_view_test.dart`** — added/removed lines carry the new palette
  colors (pump under a known theme, assert via the gutter glyph / found text);
  identical-bodies note; too-large banner; header-delta summary count.
- **`response_body_view_compare_test.dart`** (or extend existing) — Compare
  button visible only with a response; disabled with no targets; tapping with a
  target opens the picker; regression: existing Copy/Save/Save-as-example
  buttons and large-mode behavior unchanged.

Done-bar (CLAUDE.md §5): `fvm flutter analyze` (VGA), `fvm dart run custom_lint`,
`fvm dart run bloc_tools:bloc lint lib`, `fvm dart format`, and
`fvm flutter test` all clean/green. (No bloc changes, so bloc_lint surface is
unchanged; the new code is widgets + pure utils.)

## Wiki

Per the "Keep the wiki in sync" mandate (CLAUDE.md §7), this adds a user-visible
feature. Add/update a page in the `Getman.wiki.git` repo documenting **Response
diff**: how to open it (the Compare button on the response BODY pane, verbatim
tooltip "Compare response"), what targets are offered (saved examples of the
linked request + recent matching history), how the diff reads (green = added on
target, red = removed from current; status/header summary), and the limits
(line-level on pretty-printed bodies; responses over 512 KB show a summary only).
Add it to `_Sidebar.md` if it warrants its own page; otherwise fold it into the
existing Response/Collections page. Use verbatim UI labels.
