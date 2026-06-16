# Global Fuzzy Search (Command Palette Expansion) — Design

**Date:** 2026-06-15
**Status:** Approved (autonomous design)

## Goal

Broaden discovery in the existing Cmd/Ctrl+K command palette. Today the palette
fuzzy-jumps to **saved requests** (matched by name + collection path),
**environments**, and **themes**. This expansion:

1. Adds **request history** entries as searchable results that open as a tab.
2. Widens saved-request matching to also include the request **URL** and
   **HTTP method**, not just name + path.

This is an **enhancement of the existing palette surface** — not a new screen,
overlay, or shortcut. Arrow-key navigation, fuzzy ranking, debounced query, and
theming-via-`context.app*` are all preserved unchanged.

## Scope

In scope:

- A new **History source** appended to the palette's command list, alongside the
  existing request / environment / theme sources.
- **Widened match string** for saved-request commands: name + path **+ method +
  URL**.
- Wiring `HistoryBloc` into `CommandPalette.show` (it is already provided at the
  root `MultiBlocProvider` in `main.dart`, so it is reachable via
  `context.read<HistoryBloc>()` at the `CommandPaletteIntent` action site).
- Opening a selected history entry as an **unlinked** tab from its stored
  (templated) config — identical to the existing History drawer behavior.

Out of scope (explicit non-goals, locked):

- **Full body/header content scan across all configs.** v1 does **not** search
  request *body text* or *header values/keys*. Locked rationale below
  (Locked Decision 3). Noted as a deferred follow-up.
- **Searching response bodies / response content.** Out of scope; the palette is
  a "jump to a thing" surface, not a content grep.
- **A new bloc, a new event, or a new persistence path.** The palette continues
  to read bloc state at open time and dispatch existing events only
  (CLAUDE.md §2, command_palette note: "Reads bloc state at open time; dispatches
  existing events (no new bloc)").
- **A new keyboard shortcut or a second palette mode.** Same Cmd/Ctrl+K, same
  single result list.
- **Sub-source filters / scoped search syntax** (e.g. `>req`, `@env`). Deferred;
  a flat ranked list is kept.

## Existing behavior (verified against code)

- `command_palette.dart` builds a flat `List<_Command>` in `_buildCommands()`:
  requests (recursed via `_collectRequests`), then a synthetic "No Environment"
  + each environment, then each theme. Each `_Command` is
  `{label, subtitle, icon, run}`.
- Filtering/ranking: `FuzzyMatcher.filter(query, _all, (c) => '${c.label} ${c.subtitle}')`
  — the **match string is `label + ' ' + subtitle`**. `FuzzyMatcher.score` is a
  subsequence matcher; word-boundary hits (after space/`/`/`_`/`-`/`.`) score
  higher; empty query returns all in insertion order; ties break by insertion
  index (stable).
- Saved request `run`: `widget.tabsBloc.add(AddTab(config: config, collectionNodeId: node.id, collectionName: node.name))`
  — a **linked** tab (carries the node id + name).
- History drawer (`history_list.dart`) opens an entry via
  `context.read<TabsBloc>().add(AddTab(config: config.copyWith()))` — **no**
  `collectionNodeId`/`collectionName`, i.e. an **unlinked** tab. The
  `copyWith()` produces a fresh config object that still carries the stored
  response columns (`responseBody`/`responseHeaders`/`statusCode`/`durationMs`).
- A history entry **is** an `HttpRequestConfigEntity` (no dedicated history
  entity). `HistoryState.history` is `List<HttpRequestConfigEntity>`, newest
  first (repository reverses insertion order). The list streams in via
  `watchHistory()`; `isLoading` starts `true` until the first emission
  (CLAUDE.md §4.4).

## Locked Decisions

1. **Enhancement, not a new surface.** The History source and widened request
   match live entirely inside the existing `CommandPalette` widget + its
   `_buildCommands`/`_collectRequests` helpers and the `FuzzyMatcher.filter`
   call. No new dialog, route, shortcut, or bloc. *Justification:* the palette is
   explicitly designed as a stateless reader of bloc snapshots that dispatches
   existing events; adding sources is the intended extension point.

2. **Saved-request match string = `name + path + method + URL`.** The match
   string fed to `FuzzyMatcher` for request commands becomes
   `'${label} ${subtitle} ${method} ${url}'` (label = node name, subtitle =
   collection path or `Request`). *Justification:* method + URL are already in
   hand (`node.config.method` / `node.config.url`), so this is O(1) string
   concatenation per command — no extra traversal cost. It lets users find "the
   POST to /orders" without remembering its saved name. The **displayed**
   label/subtitle are unchanged; only the hidden match text widens.

3. **Exclude full body/header content scan in v1 (deferred).** The match string
   includes URL + method but **not** body text, header values, or header keys.
   *Justification:* (a) body content can be large (multi-KB JSON) and is held by
   every config across collections + history — concatenating all of it into one
   match string per command on every keystroke-after-debounce is a real cost and
   muddies ranking (a stray word in a payload outscores a title hit); (b) URL +
   method already cover the overwhelming majority of "find my request" intents;
   (c) `FuzzyMatcher` is a subsequence matcher with no field weighting, so noisy
   long fields degrade precision. Deferred as a follow-up if demand appears
   (would likely need per-field weighting first).

4. **History results open an UNLINKED tab from the stored (templated) config.**
   The `run` callback is exactly
   `widget.tabsBloc.add(AddTab(config: config.copyWith()))` — matching
   `history_list.dart` verbatim: no `collectionNodeId`, no `collectionName`.
   *Justification:* a history entry is not a saved collection node, so it must
   not link to one (linking would make re-sends compare against / overwrite a
   node). `copyWith()` clones the config (carrying response columns so the tab
   shows the prior response) without resolving env vars — history stores the
   **templated** config (CLAUDE.md §4.10 / §6: "Never resolve env vars in
   `SendRequestUseCase._record`"), and re-opening preserves that so the user can
   re-send under a different environment.

5. **History command labeling.** Each history command renders:
   - `label` = the entry's URL (or `(NO URL)` when empty, mirroring
     `history_list.dart`'s `_HistoryItemWidget`).
   - `subtitle` = the literal string `History` (the source tag — consistent with
     `Request` / `Environment` / `Theme` subtitles already used as the source
     label).
   - `icon` = `Icons.history`.
   - The match string is `'${url} History ${method}'` so a user can fuzzy-match
     by URL or method (and the subtitle tag, like the other sources).
   *Justification:* URL-as-title matches the History drawer's own row layout and
   is the most recognizable field; `History` as subtitle makes the source
   obvious in a mixed result list and keeps the subtitle a stable source tag
   like every other command.

6. **History dedupe within the palette = none beyond what the box already does.**
   The data layer already dedupes on `method + url + body`
   (`HistoryLocalDataSourceImpl.addToHistory`, CLAUDE.md §4.4), so
   `HistoryState.history` contains no `method+url+body` duplicates. The palette
   does **not** add a second dedupe pass and does **not** merge history entries
   with saved-request commands. *Justification:* a history entry and a saved
   request that happen to share a URL are genuinely different things (one is
   unlinked + carries a response snapshot, one is a linked collection node); the
   distinct subtitle tags (`History` vs `Request`/path) disambiguate them. Two
   history entries differing only by headers are intentionally retained (the box
   does not dedupe on headers) — they will surface as two rows with the same
   label; acceptable and rare.

7. **History command list ordering = newest-first, after request/env/theme
   sources, before fuzzy ranking.** History commands are appended to `_all`
   after the existing sources, in `HistoryState.history` order (already
   newest-first). For a non-empty query, `FuzzyMatcher` re-ranks everything by
   score (insertion index is only the tie-breaker), so source append-order only
   affects the *empty-query* list. *Justification:* with an empty query the user
   sees requests → environments → themes → recent history, a sensible "browse"
   order; with a query, relevance wins.

8. **History list size is not capped by the palette.** The palette consumes
   `HistoryState.history` as-is; the global `historyLimit` setting already bounds
   the box (CLAUDE.md §4.4 trim loop). *Justification:* no second limit needed;
   honoring the user's configured history depth is correct.

## Architecture

All changes are confined to the command_palette feature plus its `show()`
wiring. No domain/data layer changes, no new entity, no theme-extension changes
(every value already comes from `context.app*`).

### 1. `CommandPalette.show` — add `HistoryBloc`

`show(BuildContext)` currently reads `TabsBloc`, `CollectionsBloc`,
`EnvironmentsBloc`, `SettingsBloc` via `context.read<...>()` and passes them as
constructor args. Add a `historyBloc: context.read<HistoryBloc>()` read and a
`final HistoryBloc historyBloc;` field on the widget.

`HistoryBloc` is already in scope at the call site: `main.dart` provides it in
the root `MultiBlocProvider` (`BlocProvider(create: (_) => di.sl<HistoryBloc>())`),
and `CommandPalette.show(context)` is invoked from the `CommandPaletteIntent`
`CallbackAction` under that provider tree. No DI or provider change needed.

### 2. `_buildCommands()` — append a History source

After the theme loop, append one `_Command` per entry in
`widget.historyBloc.state.history`:

```
for (final config in widget.historyBloc.state.history) {
  cmds.add(
    _Command(
      label: config.url.isEmpty ? '(NO URL)' : config.url,
      subtitle: 'History',
      icon: Icons.history,
      // Match string carries method too (see _resultsFor below).
      matchExtra: '${config.method}',
      run: () => widget.tabsBloc.add(AddTab(config: config.copyWith())),
    ),
  );
}
```

`_buildCommands()` runs **once** in `late final List<_Command> _all = _buildCommands();`
(field initializer), so the history snapshot is taken at palette-open time —
consistent with how requests/environments/themes are already snapshotted. The
palette is short-lived (a modal dialog), so a mid-session box update not
reflecting in an already-open palette is acceptable and matches existing
behavior for the other sources.

### 3. Widen the match string (requests + history)

The match function is currently `(c) => '${c.label} ${c.subtitle}'`. To include
method/URL without changing the **displayed** label/subtitle, add an optional
`final String matchExtra;` field to `_Command` (default `''`) and change the
filter projection to include it:

```
String _matchString(_Command c) =>
    c.matchExtra.isEmpty ? '${c.label} ${c.subtitle}'
                         : '${c.label} ${c.subtitle} ${c.matchExtra}';
```

Used in both `_resultsFor`:
`FuzzyMatcher.filter(query, _all, _matchString)`.

- **Saved requests** set `matchExtra: '${config.method} ${config.url}'` in
  `_collectRequests`.
- **History** sets `matchExtra: config.method` (URL is already the `label`).
- Environments/themes leave `matchExtra` at its `''` default — match behavior
  unchanged.

This keeps the visible rows identical while widening what the fuzzy matcher
sees. `_Command` stays a small immutable value type (no behavior change to
`run`/`icon`).

### 4. Nothing else changes

- Arrow-key nav (`_MoveSelectionIntent`/`_RunSelectionIntent`), the debounced
  `_queryText`/`_selected` notifiers, the `_currentResults` cache, and the
  `ListView.builder` rows are untouched.
- Theming: history rows reuse the same `ListTile` row builder, so they pick up
  `context.appLayout.iconSize`, `context.appTypography.titleWeight`, and the
  primary highlight tint already in `_buildScaffold` — no hardcoded values, no
  new theme fields.
- The hint text (`'Jump to a request, environment, or theme…'`) is updated to
  `'Jump to a request, history entry, environment, or theme…'` (a user-facing
  label change — see Wiki). Pulled from a literal in the same place it lives
  today (this is plain copy in the widget, not a themed token).

## Data flow

```
CommandPaletteIntent action (main.dart, under root MultiBlocProvider)
  └─ CommandPalette.show(context)
       reads: TabsBloc, CollectionsBloc, EnvironmentsBloc, SettingsBloc, HistoryBloc
       └─ _buildCommands()  (once, at open)
            ├─ _collectRequests(collections)  → request _Commands
            │     matchExtra = "<method> <url>"   (Locked Decision 2)
            ├─ environments → env _Commands
            ├─ themes → theme _Commands
            └─ historyBloc.state.history → history _Commands  (newest-first)
                  label = url | "(NO URL)", subtitle = "History",
                  matchExtra = "<method>", run = AddTab(config.copyWith())  (unlinked)
       └─ on query: FuzzyMatcher.filter(query, _all, _matchString)
       └─ on select/Enter: _invoke → command.run() → Navigator.maybePop()
```

## Error handling / edge cases

- **Empty history (`history == []`):** the loop appends nothing; palette behaves
  exactly as today (requests/envs/themes only). No empty-state row is added.
- **History still loading (`isLoading == true`, list empty):** the palette opens
  with whatever `state.history` currently holds (empty until the first stream
  emission). Because `watchHistory()` yields the current list on subscribe and
  `HistoryBloc` is created eagerly at app boot, by the time the user can press
  Cmd/Ctrl+K the box has virtually always emitted. No spinner is shown in the
  palette (it is a snapshot reader); acceptable.
- **History entry with empty URL:** label falls back to `(NO URL)` (mirrors the
  drawer). It is still openable; `matchExtra` (method) keeps it fuzzy-findable.
- **Two history entries differing only by headers:** both appear (box does not
  dedupe on headers — Locked Decision 6). Same label, distinct rows; opening
  either creates its own unlinked tab. Acceptable and rare.
- **A history URL equal to a saved request's URL:** both rows appear with
  different subtitles (`History` vs the collection path / `Request`). No merge
  (Locked Decision 6).
- **Selected index out of range after results reorder:** unchanged — existing
  `_runSelected` already clamps `_selected.value` to `results.length - 1`, and
  `_selected` resets to 0 on query change.
- **Opening from the palette closes it:** `_invoke` already calls
  `Navigator.of(context).maybePop()`; history `run` (an `AddTab` dispatch)
  behaves like every other command.
- **Very large history (at `historyLimit`):** one `_Command` per entry +
  per-keystroke (post-debounce) `FuzzyMatcher` pass over all commands. The
  matcher is O(total chars) and the match strings stay short (URL + method, no
  body — Locked Decision 3), so this is comfortably within the existing
  palette's cost envelope.

## Testing

Widget tests (palette is presentation-only; the changes are not pure logic, so
the bulk is widget-level). Use real/stub blocs seeded with fixed state, matching
existing command_palette tests.

- **History entry appears + opens (unlinked).** Seed `HistoryBloc` state with a
  known entry (e.g. method `POST`, url `https://api.example.com/orders`). Open
  the palette, type a fuzzy fragment of the URL, assert a row with subtitle
  `History` appears. Tap it (or Enter on the highlighted row) and assert
  `TabsBloc` received an `AddTab` whose `config.url`/`config.method` match and
  whose `collectionNodeId == null` && `collectionName == null` (the unlinked
  assertion — Locked Decision 4). Assert the palette popped.
- **Request matches by URL (not just name).** Seed `CollectionsBloc` with a leaf
  node whose **name** is unrelated to its URL (e.g. name `Foo`, url
  `https://api.example.com/widgets`). Type a fragment of the URL (`widgets`) and
  assert the request row surfaces — proving the widened match string
  (Locked Decision 2).
- **Request matches by method.** Seed a leaf with method `DELETE`; type `delete`
  and assert it surfaces.
- **Empty history is a no-op.** With empty `HistoryBloc` state, assert the
  palette still shows request/env/theme results and no `History`-subtitled row.
- **Existing behavior regression.** Environment + theme rows still appear and
  still dispatch `UpdateActiveEnvironmentId` / `UpdateThemeId`; arrow-key nav and
  `NO MATCHES` empty-results state are unchanged. (Keep existing palette tests
  green.)

Full project done-bar (CLAUDE.md §5): `fvm flutter analyze` (very_good_analysis),
`fvm dart run custom_lint`, `fvm dart run bloc_tools:bloc lint lib`,
`fvm dart format` clean, and `fvm flutter test` all green.

## Wiki

Per the "Keep the wiki in sync" mandate (CLAUDE.md §7), this changes how a
feature is *used* (the palette now also finds history entries and matches
requests by URL/method) and changes a user-facing label (the search hint text).
Update the Command Palette page in the `Getman.wiki.git` repo (and `_Sidebar.md`
if that page's summary lists the searchable sources): document that Cmd/Ctrl+K
now also searches **history** (opens as a new tab) and matches saved requests by
**method + URL** in addition to name + path. Use the verbatim hint text
`Jump to a request, history entry, environment, or theme…`.
