# Quick Environment Switcher — Design

**Date:** 2026-06-15
**Status:** Approved (autonomous design)

## Goal

Give the user a **fast, keyboard-driven way to switch the active environment**
without leaving the keyboard or opening the full Cmd/Ctrl+K command palette. A
dedicated shortcut (**Cmd/Ctrl+E**) opens a minimal modal overlay: an
arrow-navigable list of `No Environment` + every saved environment, with the
currently-active one visibly marked. Up/Down moves the highlight, **Enter**
selects (dispatches the switch and closes), **Esc** dismisses without changing
anything.

This complements — does not replace — the two existing affordances:

- the **dropdown** `EnvironmentSelector`
  (`lib/features/environments/presentation/widgets/environment_selector.dart`),
  a mouse-first `PopupMenuButton`; and
- the **Cmd/Ctrl+K command palette**
  (`lib/features/command_palette/presentation/widgets/command_palette.dart`),
  which already lists environments alongside requests + themes behind a fuzzy
  search.

The quick switcher is a **smaller sibling of the command palette**: same
overlay / Shortcuts+Actions / arrow-key pattern, same "read blocs at open time,
dispatch existing events" approach, but scoped to environments only and with
**no text search**.

## Scope

In scope:

- A new **`QuickEnvSwitcher`** modal widget (a focused, environments-only
  sibling of `CommandPalette`).
- A new **`SwitchEnvironmentIntent`** + its **Cmd/Ctrl+E** activator in
  `appShortcuts`, with the `Action` wired at the **root** (in `main.dart`,
  alongside `CommandPaletteIntent`).
- Keyboard navigation (Up/Down/Enter) inside the overlay, mirroring the command
  palette's `_MoveSelectionIntent` / `_RunSelectionIntent`.
- Marking the active row and **auto-highlighting it on open** (so a single Enter
  is a no-op confirm, and Up/Down starts from where you are).

Out of scope (explicit non-goals):

- **Fuzzy / type-to-filter search.** The list is short (No Environment + N
  envs); a plain arrow-navigable list is faster to reason about and avoids
  pulling `FuzzyMatcher` + a debounced query field into a tiny overlay. If a
  future need arises, reuse `FuzzyMatcher` (as the command palette does) — but
  that is a separate, justified change, not part of this feature. **Locked:
  no filter field.**
- **Creating / editing / deleting environments.** Those stay in
  `EnvironmentsDialog`. The switcher offers no "Manage environments…" row
  (unlike the dropdown) — it is a pure switcher. (Locked; keeps the overlay
  single-purpose and the keyboard model trivial.)
- **Changing where the active id is stored.** It remains
  `SettingsEntity.activeEnvironmentId` (CLAUDE.md §4.10); the switcher only
  dispatches `UpdateActiveEnvironmentId`.
- **A new bloc.** Like the command palette, the switcher reads the two existing
  blocs at open time and dispatches an existing event. No `data/`, no use case,
  no new domain entity.

## Shortcut choice (verified free)

The global activator→intent map is `appShortcuts` in `lib/main.dart`
(`@visibleForTesting`, built — not const — so the digit bindings can be looped).
Auditing the currently-bound Cmd/Ctrl letters there:

| Key | Intent |
|---|---|
| N | NewTabIntent |
| W | CloseTabIntent |
| S | SaveRequestIntent |
| Enter | SendRequestIntent |
| B | BeautifyJsonIntent |
| K | CommandPaletteIntent |
| L | FocusUrlIntent |
| Tab / Shift+Tab | Next/PrevTabIntent |
| 1–9 | JumpToTabIntent(i) |

**`keyE` is unbound** (verified: `grep -n keyE lib/main.dart` returns nothing).
**Locked decision: Cmd/Ctrl+E** ("E" for Environment) — a strong mnemonic, free
on both meta (macOS) and control (Windows/Linux), and consistent with the
existing both-modifier pattern (every letter shortcut registers a `meta:` *and*
a `control:` variant). It does not collide with any
`DefaultTextEditingShortcuts` binding the app relies on (those are caret/edit
keys, not Cmd/Ctrl+E for our targets).

## Overlay widget structure

A single new file:
`lib/features/environments/presentation/widgets/quick_env_switcher.dart`.

It deliberately mirrors `CommandPalette`'s skeleton so the patterns stay
uniform:

```
class QuickEnvSwitcher extends StatefulWidget {
  const QuickEnvSwitcher({
    required this.environments,   // snapshot read at open time
    required this.activeId,       // snapshot read at open time
    required this.settingsBloc,   // for dispatching the switch
    super.key,
  });
  final List<EnvironmentEntity> environments;
  final String? activeId;
  final SettingsBloc settingsBloc;

  static Future<void> show(BuildContext context) {
    final envState = context.read<EnvironmentsBloc>().state;
    final settingsBloc = context.read<SettingsBloc>();
    return showResponsiveDialog<void>(
      context,
      builder: (_) => QuickEnvSwitcher(
        environments: envState.environments,
        activeId: settingsBloc.state.settings.activeEnvironmentId,
        settingsBloc: settingsBloc,
      ),
    );
  }
}
```

Why these inputs:

- **Read blocs at open time, not via `BlocBuilder`.** The command palette does
  exactly this (`CommandPalette.show` reads `context.read<...>()` and passes the
  bloc/state in). The switcher is transient; the env list will not meaningfully
  change while it is open, and snapshotting keeps the widget pure + trivially
  testable (pass a fixed list/active id, no bloc plumbing in the widget test for
  the list itself).
- **Pass `settingsBloc` (the bloc, not a callback)** so the widget dispatches
  `UpdateActiveEnvironmentId` itself — same as `CommandPalette` holds
  `settingsBloc` and calls `settingsBloc.add(UpdateActiveEnvironmentId(...))`.
- **`EnvironmentsBloc` is read for state only** (the list), so it is *not*
  retained as a field — only its `.state.environments` snapshot. This matches
  the brief's "reads environments + active id" and keeps the field set minimal.

### Rows model

A small private union so `No Environment` and real environments share one list
+ selection index, with no magic-string sentinels leaking into the keyboard
code:

```
class _EnvRow {
  const _EnvRow({required this.label, required this.envId, required this.isActive});
  final String label;     // 'No Environment' or env.name
  final String? envId;    // null == the No Environment row
  final bool isActive;    // envId == activeId
}
```

Rows are built once in `initState`:

1. `_EnvRow(label: 'No Environment', envId: null, isActive: activeId == null)`
   — always first (matches the dropdown + palette ordering).
2. one `_EnvRow` per `environments` entry, in list order, `isActive: env.id == activeId`.

`'No Environment'` is the verbatim label used by the dropdown and the palette —
reuse it for consistency (not a localized/new string).

### Selection state + initial highlight

- `final ValueNotifier<int> _selected;` initialized in `initState` to the index
  of the active row (`rows.indexWhere((r) => r.isActive)`, falling back to `0`).
  **Locked: open with the active environment pre-highlighted** so the list opens
  "where you are" and a stray Enter is a harmless re-select.
- `_moveSelection(int delta)` clamps to `[0, rows.length - 1]` — identical shape
  to the palette's `_moveSelection`.
- `_runSelected()` dispatches the row at `_selected.value` and pops (see Data
  flow). No live-text recompute needed (there is no query), so it reads
  `_selected.value` directly.

### Chrome

Built with **`ResponsiveDialogScaffold`** (the same responsive AlertDialog ↔
fullscreen-page wrapper the palette uses via `showResponsiveDialog`):

- `title: const Text('SWITCH ENVIRONMENT')`.
- `content`: a `SizedBox(width: context.isDialogFullscreen ? double.maxFinite :
  <palette-width>)` wrapping a `ConstrainedBox(maxHeight: …)` + a
  `ListView.builder` over the rows. The width/maxHeight numbers must come from
  the theme, not literals — see "Theming" below.
- Each row is a `ListTile` (dense) inside a `ColoredBox` whose color is the
  selection highlight when `i == selected`, transparent otherwise — copied from
  the palette's row builder (`Theme.of(context).colorScheme.primary.withValues(
  alpha: …)` for the highlight).
  - `leading`: a check icon (`Icons.check`) on the active row, else a
    same-width `SizedBox` spacer — matching the dropdown's active-marker
    pattern (`environment_selector.dart` `_menuItems`), themed via
    `context.appPalette` / `colorScheme.secondary` for the check color and
    `layout.smallIconSize` for size.
  - `title`: `Text(row.label, maxLines: 1, overflow: ellipsis,
    fontWeight: context.appTypography.titleWeight)`.
  - `onTap: () => _invoke(i)` (mouse parity — tapping a row selects it).
- A single `CLOSE` `TextButton` action (parity with the env/palette dialogs;
  Esc also dismisses via the route's default barrier/back behavior).

### Keyboard nav + selection (mirrors CommandPalette)

Wrap the scaffold in `Shortcuts` → `Actions`, reusing the palette's private
intents pattern verbatim (defined privately in this file; they are not shared
atoms):

```
Shortcuts(
  shortcuts: const <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowDown): _MoveSelectionIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _MoveSelectionIntent(-1),
    SingleActivator(LogicalKeyboardKey.enter): _RunSelectionIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): _RunSelectionIntent(),
  },
  child: Actions(
    actions: {
      _MoveSelectionIntent: CallbackAction(onInvoke: (i) { _moveSelection(i.delta); return null; }),
      _RunSelectionIntent: CallbackAction(onInvoke: (_) { _runSelected(); return null; }),
    },
    child: _buildScaffold(context),
  ),
)
```

Because there is **no text field** to compete for arrow/Enter keys, focus
handling is simpler than the palette: the overlay requests focus on open (an
`autofocus: true` `Focus`/`FocusScope` wrapper, or `autofocus` on the list) so
the `Shortcuts` resolve immediately without the user clicking first. (The
palette relies on its autofocused `TextField`; we have none, so an explicit
autofocus node is the equivalent.) **Locked: an autofocused `Focus` wrapper, no
search field.**

## Data flow

```
Cmd/Ctrl+E
  └─ appShortcuts → SwitchEnvironmentIntent
       └─ root Action (main.dart) → QuickEnvSwitcher.show(context)
            ├─ reads EnvironmentsBloc.state.environments  (snapshot)
            └─ reads SettingsBloc.state.settings.activeEnvironmentId (snapshot)
                 └─ overlay builds _EnvRow list, highlights active
                      └─ Up/Down move highlight; Enter/tap → _invoke(i):
                           settingsBloc.add(
                             UpdateActiveEnvironmentId(row.envId)   // null for "No Environment"
                           )
                           Navigator.of(context).maybePop()
```

`UpdateActiveEnvironmentId(this.id)` already accepts a nullable id
(`UpdateActiveEnvironmentId(null)` = No Environment); the `EnvironmentSelector`
and `CommandPalette` both dispatch it exactly this way. The switcher reuses it
unchanged. `SettingsBloc` persists immediately on every `Update*`
(CLAUDE.md §4.5), and the dropdown's `EnvironmentSelector` rebuilds via its
`buildWhen` on `activeEnvironmentId` — so after the switcher pops, the dropdown
label and all send-time resolution reflect the new active env with no extra
wiring.

### Two-bloc coordination at the widget layer

The feature touches **two blocs** — it reads `EnvironmentsBloc` (the list) and
writes `SettingsBloc` (the active id). Per CLAUDE.md, this coordination happens
at the **widget layer, never bloc→bloc**, following
`EnvironmentsDialog._deleteEnvironment` (which reads `SettingsBloc.state` and
conditionally dispatches `UpdateActiveEnvironmentId(null)` from the widget). Here
the coordination is even looser: the widget reads one bloc's state at open time
and dispatches to the other on selection. No `BlocListener`/`BlocBuilder`
cross-wiring, no service in between.

### Where the Action lives

Both required blocs (`EnvironmentsBloc`, `SettingsBloc`) are provided at the
**root** `MultiBlocProvider` in `main.dart`, so `context.read<...>()` for both
is reachable in the root `Actions` map — exactly where `CommandPaletteIntent`'s
action already lives and calls `CommandPalette.show(context)`. Therefore:

**Locked: `SwitchEnvironmentIntent`'s `Action` is registered at the root,
next to `CommandPaletteIntent`, invoking `QuickEnvSwitcher.show(context)`.**
It does **not** go in `MainScreen` or `RequestView` (those are for intents
needing `activeIndex`/`tabs`/`UrlFocusRegistry`/per-tab env resolution, which
this intent does not).

New intent in `lib/core/navigation/intents.dart`:

```
/// Open the quick environment switcher overlay. Bound to Cmd/Ctrl+E.
class SwitchEnvironmentIntent extends Intent {
  const SwitchEnvironmentIntent();
}
```

New activators in `appShortcuts` (both modifiers, matching the existing style):

```
const SingleActivator(LogicalKeyboardKey.keyE, control: true):
    const SwitchEnvironmentIntent(),
const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
    const SwitchEnvironmentIntent(),
```

New root action in `main.dart` `Actions`:

```
SwitchEnvironmentIntent: CallbackAction<SwitchEnvironmentIntent>(
  onInvoke: (intent) {
    unawaited(QuickEnvSwitcher.show(context));
    return null;
  },
),
```

## Error handling / edge cases

- **No environments saved:** the row list is just `[No Environment]` (always
  present, `isActive: activeId == null`). The overlay still opens and is fully
  usable — selecting it dispatches `UpdateActiveEnvironmentId(null)` (a no-op if
  already null) and closes. No empty/error state needed. (Distinct from the env
  *editor*, which shows an empty-state prompt; the switcher always has at least
  one row.)
- **Already-active row selected (Enter on the pre-highlighted row):** dispatches
  `UpdateActiveEnvironmentId(<sameId>)`. `SettingsBloc` re-emits with an equal
  `activeEnvironmentId`; `EnvironmentSelector`'s `buildWhen` (`p != n`) yields
  `false`, so nothing rebuilds. Harmless re-confirm — no special-casing.
- **Active id points at a since-deleted env (stale):** can only happen if the
  env list and active id are momentarily out of sync at open time. The active
  row simply won't match (`indexWhere` returns `-1`), so `_selected` falls back
  to `0` (the `No Environment` row). No crash; the dropdown's `_activeLabel()`
  already degrades the same way ("No Environment" when the id isn't found).
- **Esc / barrier tap:** dismisses via the route without dispatching anything
  (`showResponsiveDialog` uses a dismissible barrier; the fullscreen variant's
  back button pops). The active environment is unchanged.
- **Empty selection guard:** the row list is never empty (No Environment is
  always present), so `_runSelected` needs no empty guard — but it still clamps
  the index defensively before indexing, mirroring the palette.
- **Opening twice (double Cmd+E):** the route is a standard modal; a second
  invocation while open pushes another modal only if the platform allows — the
  same behavior as Cmd+K today. No new guard is added (parity with the existing
  command palette; out of scope to change).

## Theming (no hardcoded values)

Everything is pulled through the `context.app*` extensions, exactly as the
palette + dropdown do:

- **Highlight color:** `Theme.of(context).colorScheme.primary.withValues(alpha:
  …)` — copy the palette's existing highlight treatment. (The alpha is the same
  literal the palette uses; if reviewers prefer it tokenized, add a
  `selectionOverlayAlpha`/color to `AppPalette` and update both call sites — but
  matching the palette's current literal is acceptable since it is the
  established pattern. **Locked: match `CommandPalette`'s highlight exactly** to
  avoid a one-off divergence.)
- **Active-row check color:** `colorScheme.secondary` + `layout.smallIconSize`
  (matches `EnvironmentSelector._menuItems`).
- **Spacing / icon sizes / font weights:** `context.appLayout.*`
  (`sectionSpacing`, `iconSize`, `smallIconSize`, `pagePadding`) and
  `context.appTypography.titleWeight` — never literals.
- **Overlay width / max list height:** the palette currently uses literal `520`
  width and `maxHeight: 360`. To stay within the "no hardcoded sizes" mandate
  for *new* code, the switcher reads these from `context.appLayout`. The cleanest
  option is to **reuse the existing `AppLayout.dialogWidth`** for the width (the
  env dialog already sizes off `layout.dialogWidth`). For the list cap, if no
  suitable field exists, **add a field to `AppLayout`** (e.g.
  `quickListMaxHeight`, set per theme) rather than hardcoding `360`. (Locked:
  prefer an existing `AppLayout` field; add one to the extension only if none
  fits — never a literal.)

## Wiki

Per the "Keep the wiki in sync" mandate (CLAUDE.md §7): this adds a new
user-visible feature (a keyboard shortcut + overlay) and a new keyboard
shortcut. Update the wiki as part of the work in the `Getman.wiki.git` repo:

- Add **Cmd/Ctrl+E — Quick environment switcher** to the keyboard-shortcuts
  reference (alongside Cmd/Ctrl+K).
- Add a short blurb to the **Environments** page describing the switcher
  (arrow-navigate the list of `No Environment` + your environments, Enter to
  switch, Esc to cancel) as a third way to change the active environment beside
  the dropdown and the command palette.
- Use the verbatim UI label **SWITCH ENVIRONMENT** and **No Environment**.

## Testing

Done-bar (CLAUDE.md §5): `fvm flutter analyze` (very_good_analysis) +
`fvm dart run custom_lint` + `fvm dart run bloc_tools:bloc lint lib` +
`fvm dart format` + `fvm flutter test` all clean.

- **Widget test — open, navigate, select, dispatch** (the core test required by
  the brief). Pump `QuickEnvSwitcher` with a fixed `environments` list, a known
  `activeId`, and a mock/real `SettingsBloc` (use `bloc_test`/`mocktail` per the
  project's existing test style):
  - Asserts all rows render (`No Environment` + each env name), and the active
    row shows the check marker.
  - Asserts the active row is pre-highlighted on open.
  - Sends `arrowDown` × N and `enter`; asserts `UpdateActiveEnvironmentId(<expected
    id>)` is added to `SettingsBloc` and the overlay pops
    (`findsNothing` after settle).
  - Sends `enter` immediately (no movement) on a non-null-active fixture;
    asserts the active id is re-dispatched (or, if testing via `bloc_test`,
    that the event fired) and the overlay pops.
  - Selecting the `No Environment` row dispatches `UpdateActiveEnvironmentId(null)`.
  - **No-environments fixture:** only the `No Environment` row renders; selecting
    it dispatches `UpdateActiveEnvironmentId(null)` and pops.
  - Tap parity: tapping a row dispatches the same event as Enter on it.
- **Shortcut wiring test** (extend the existing `appShortcuts` test if one
  exists, or add one): assert `appShortcuts` contains the Cmd+E and Ctrl+E
  activators mapped to `SwitchEnvironmentIntent`. (Pure map assertion — no
  widget pump needed; mirrors how the digit/jump bindings are validated.)
- **No new pure-logic unit test is strictly required** — the only "logic" is the
  `_EnvRow` build + active-index computation, which is exercised by the widget
  test. If the row-building is extracted to a tiny pure helper for testability,
  add a focused unit test for the active-index/`No Environment`-first ordering;
  otherwise the widget test covers it. (Locked: keep the row builder private to
  the widget unless extraction simplifies the test; no separate `core/utils`
  module is warranted for this.)

## Files to touch

- **New:** `lib/features/environments/presentation/widgets/quick_env_switcher.dart`
  — the `QuickEnvSwitcher` widget (`show()` + state + private `_EnvRow`,
  `_MoveSelectionIntent`, `_RunSelectionIntent`).
- **Edit:** `lib/core/navigation/intents.dart` — add `SwitchEnvironmentIntent`.
- **Edit:** `lib/main.dart` — add the two Cmd/Ctrl+E activators to
  `appShortcuts`; add the root `SwitchEnvironmentIntent` action calling
  `QuickEnvSwitcher.show`.
- **Edit (only if needed):** `lib/core/theme/app_theme.dart` +
  `lib/core/theme/themes/*/*_theme.dart` — add an `AppLayout` field for the list
  max-height **only if** no existing field fits (see Theming).
- **New test:** `test/features/environments/.../quick_env_switcher_test.dart`
  (widget test) and a shortcut-map assertion (in the existing shortcuts test or
  a new one).
- **Wiki:** keyboard-shortcuts page + Environments page in `Getman.wiki.git`.

## Locked decisions (summary)

1. **Shortcut: Cmd/Ctrl+E** (verified unbound in `appShortcuts`), both modifiers.
2. **No fuzzy/text filter** — plain arrow-navigable list; do not pull in
   `FuzzyMatcher`/debounced field.
3. **Read both blocs' state at open time, snapshot into the widget**; dispatch
   `UpdateActiveEnvironmentId` on the held `SettingsBloc`. No new bloc.
4. **Action at the root** in `main.dart`, beside `CommandPaletteIntent` (both
   blocs are root-provided).
5. **Open with the active row pre-highlighted**; `No Environment` always first.
6. **No "Manage environments…" / create / delete** in the switcher — pure
   switcher, single purpose.
7. **Two-bloc coordination at the widget layer**, following
   `EnvironmentsDialog._deleteEnvironment`.
8. **All sizes/colors via `context.app*`**; add an `AppLayout` field for the
   list height only if none exists — never a literal.
9. **Reuse `ResponsiveDialogScaffold` + `showResponsiveDialog`** and the
   palette's `Shortcuts`/`Actions`/`_Move`/`_Run` pattern.
