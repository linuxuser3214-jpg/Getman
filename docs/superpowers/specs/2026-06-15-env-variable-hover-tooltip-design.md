# Env Variable Hover Tooltip — Design

**Date:** 2026-06-15
**Status:** Approved (brainstorming)

## Goal

When the user hovers the mouse over an environment-variable token (`{{var}}`)
in the request UI, show a popover revealing the **actual value that will be
used** at send time, based on the currently active environment.

## Scope

In scope (hover target surfaces):

- **URL bar** — already highlights `{{var}}` tokens via
  `VariableHighlightController`.
- **Params value fields** and **Headers value fields** — the value `TextField`s
  inside `KeyValueListEditor`. These gain `{{var}}` highlighting (which they
  lack today) plus the hover popover.

Out of scope (explicit non-goals):

- **Request body** (`re_editor`) — no per-token hover hook today; deferred.
- **Param/header *key* fields** — keys are not resolved at send time
  (substitution scope is values only, per CLAUDE.md §4.10), so no
  highlighting/hover there.
- **Environment-variable *definition* editor** — the same `KeyValueListEditor`
  backs env vars, but you set values there rather than reference them;
  resolving-on-hover would be circular. Highlighting/hover stays **off** when
  the variable context is not supplied (env editor passes none).
- **Touch / mobile** — hover is desktop-only. On touch devices there is simply
  no popover; no long-press affordance is added.

## Popover content (by classification)

The popover is **not** a stock `Tooltip` (which is non-interactive and cannot
host the secret reveal toggle). It is a small `OverlayEntry` card, themed via
`context.appDecoration.panelBox`, that stays open while the mouse is over the
token **or** the card (short dismiss grace delay).

Each hovered token name classifies into one of:

| Class | Shown |
|---|---|
| **Resolved** | the resolved value, plus a subtle source line "from *<EnvName>*" |
| **Secret** (resolved + name in `secretKeys`) | `•••••• (secret)` + an eye toggle to reveal the value (mirrors the editor's reveal) |
| **Dynamic** (`$guid`, `$timestamp`, …) | label "Generated per request" + a freshly-generated sample value |
| **Unresolved** | "Not defined in *<EnvName>*", or "No active environment" when none is active |

## Architecture

All pieces are theme-driven (no hardcoded colors/sizes/radii/weights — pulled
from `context.app*` extensions) and live where the existing patterns dictate.

### 1. Resolution helper (domain/logic)

Extend the environments feature with a classifier that, given a variable name +
the active environment, returns a small result describing its class and value.
Builds on `ActiveEnvironmentHelper` (today returns only the variables map) by
also exposing the active environment's **display name** and **secret keys**, and
on `EnvironmentResolver.isDynamic` / dynamic-sample resolution.

Result shape (illustrative):

```
enum VariableValueKind { resolved, secret, dynamic, unresolved }

class ResolvedVariable {
  final String name;
  final VariableValueKind kind;
  final String? value;          // resolved/dynamic-sample value; null if unresolved
  final String? environmentName; // active env display name (for source/"not defined" line)
}
```

Pure Dart, no Flutter — testable in isolation.

### 2. Hover popover (presentation, reusable atom)

A reusable widget under `lib/core/ui/widgets/` pairing:

- **`VariableHoverPopover`** — the card content. Renders a `ResolvedVariable`,
  including the secret mask + eye reveal toggle (local `setState` for revealed).
- **An overlay controller** — manages `OverlayEntry` show/hide with a small
  grace delay so the mouse can travel from token to card without dismissing.
  Anchored at the hovered token's position.

### 3. Hover detection wrapper

Feeds `(variableName, anchorRect/position)` into the overlay controller.
**Primary: inline-span callbacks (Approach A)** — attach
`onEnter`/`onExit`/`mouseCursor` to each `{{var}}` `TextSpan` produced by
`VariableHighlightController.buildTextSpan`, reporting the token + pointer
position to a hover sink the owning widget provides.

**Verification spike is the first implementation task:** confirm on macOS that
`RenderEditable` forwards per-span `onEnter`/`onExit` inside an editable
`TextField`. If it does not, **fall back to Approach B** — wrap the field in a
`MouseRegion`, mirror its layout in a `TextPainter`, and map the pointer
position (minus content padding, plus the field's horizontal scroll offset read
from a `ScrollController`) to a character offset, testing whether it lands
inside a token from `EnvironmentResolver.findVariables`.

Either mechanism feeds the **same** popover + resolution helper — the choice is
isolated behind the detection wrapper and does not affect content code.

### 4. Wiring

- **URL bar** (`url_bar.dart`) — already owns a `VariableHighlightController`
  and computes `_activeVariables`. Attach the detector; supply the active env
  name + secret keys to the resolution helper.
- **`KeyValueListEditor`** — add an optional `variableContext` param:

  ```
  class VariableHoverContext {
    final Map<String, String> variables;
    final Set<String> secretKeys;
    final String? environmentName;
  }
  ```

  When non-null, value fields use `VariableHighlightController` (gaining
  highlighting) and attach the detector. When null (env editor), behavior is
  unchanged. Token colors come from `context.appPalette` inside the widget, not
  from the context object.

- **`ParamsTabView` / `HeadersTabView`** (`request_editor_tabs.dart`) — compute
  the `VariableHoverContext` from `EnvironmentsBloc` + `SettingsBloc` (active
  env's variables, secret keys, display name) and pass it to the editor.

## Data flow

```
EnvironmentsBloc + SettingsBloc
   └─(active env: variables, secretKeys, name)→ VariableHoverContext
        ├─ URL bar ─────────────┐
        └─ Params/Headers value ─┤→ detector reports (name, anchor)
                                  │     └→ overlay controller shows
                                  │          VariableHoverPopover(
                                  │            ResolvedVariable from helper)
```

## Error handling / edge cases

- **No active environment:** helper returns `unresolved` with
  `environmentName == null`; popover shows "No active environment".
- **Unknown variable:** `unresolved`; popover shows "Not defined in *<EnvName>*".
  (Consistent with send-time behavior, where unknown vars are left verbatim.)
- **Secret reveal state** resets when the popover closes (no lingering revealed
  state across hovers).
- **Rapid hover across tokens:** overlay controller replaces content / re-anchors
  rather than stacking entries; only one popover at a time.
- **Field disposed / scrolled while hovered:** overlay is removed on exit and on
  widget dispose.

## Testing

- **Resolution helper** — unit tests for each `VariableValueKind`
  (resolved / secret / dynamic / unresolved / no-active-env).
- **Detection** — widget test asserting the popover appears with the right value
  when hovering a token, masks secrets, reveals on toggle, and dismisses on exit.
- **KeyValueListEditor** — regression: with `variableContext == null` behavior is
  unchanged (existing tests stay green); with it set, value fields highlight.
- Full static-analysis stack (VGA + custom_lint + bloc_lint) + `dart format` +
  `fvm flutter test` all green (project done-bar, CLAUDE.md §5).

## Wiki

Per the "Keep the wiki in sync" mandate (CLAUDE.md §7): this adds a user-visible
behavior (hover a variable to see its resolved value). Update the Environments /
Variables page in the `Getman.wiki.git` repo as part of the work.
