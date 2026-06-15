# Dracula theme — design

**Date:** 2026-06-15
**Status:** Approved (ready to implement)

## Goal

Add a fourth selectable theme, **DRACULA**, based on the popular VS Code Dracula
palette. Dark mode uses the canonical Dracula palette; light mode uses the
Dracula project's own official light companion, **Alucard**. Visual personality
is **clean & flat / VS Code-true** (soft rounded corners, thin purple-tinted
borders, gentle shadows — no brutalist hard offsets, no animation).

## Why drop-in

Both theme consumers iterate `appThemes.values`:
- `settings_dialog.dart:199` (theme picker dropdown)
- `command_palette.dart:124` (Cmd/Ctrl+K jump-to-theme)

…and the registry/contrast tests iterate all registered themes. So a new theme
needs **zero widget edits** and is automatically covered by existing tests.

## Files

New (mirrors `lib/core/theme/themes/brutalist/`):
- `lib/core/theme/themes/dracula/dracula_palette.dart` — color constants
- `lib/core/theme/themes/dracula/dracula_decorations.dart` — `draculaPanelBox` /
  `draculaTabShape` / `draculaScaffoldBackground`
- `lib/core/theme/themes/dracula/dracula_press.dart` — `DraculaPress` (subtle
  scale-to-0.98 press feedback; avoids referencing `BrutalBounce`)
- `lib/core/theme/themes/dracula/dracula_theme.dart` —
  `ThemeData draculaTheme(Brightness, {bool isCompact})`

Edited:
- `lib/core/theme/theme_ids.dart` — `const String kDraculaThemeId = 'dracula';`
- `lib/core/theme/theme_registry.dart` — import + register the descriptor
  (`displayName: 'DRACULA'`)

New test:
- `test/core/theme/themes/dracula_theme_test.dart` — builds both brightnesses,
  asserts all six `ThemeExtension`s are present (parity with brutalist's test).

Docs:
- Getman wiki Themes page — list **DRACULA** (keep-the-wiki-in-sync mandate).

## Palette (verified against the official Dracula spec)

| Role | Dark (Dracula) | Light (Alucard) |
|---|---|---|
| Background (scaffold) | `#282A36` | `#FFFBEB` |
| Surface (panels/inputs) | `#343746` | `#FFFFFF` |
| Code background | `#21222C` | `#F1ECD8` |
| Text | `#F8F8F2` | `#1F1F1F` |
| Secondary/comment text | `#6272A4` | `#6C664B` |
| Border | `#44475A` | `#CFCFDE` |
| Primary (accent) | `#BD93F9` (purple) | `#644AC9` (purple) |
| Secondary (accent) | `#FF79C6` (pink) | `#A3144D` (pink) |

Method colors (GET green / POST cyan / PUT orange / DELETE red / PATCH purple):
- Dark: `#50FA7B / #8BE9FD / #FFB86C / #FF5555 / #BD93F9`
- Light: `#14710A / #036A96 / #A34D14 / #CB3A2A / #644AC9`

Status: success=green, warning=orange, error=red (same family per brightness).
Variables: resolved=green, unresolved=red. `selectorActive`=primary purple.
`onPrimary` set explicitly: `#282A36` (dark, on light-ish purple) / white (light,
on dark Alucard purple).

## Shape / typography / decoration

- **AppShape**: `panelRadius 8, buttonRadius 6, inputRadius 6, dialogRadius 12,
  sheetRadius 16`.
- **AppTypography**: Lexend UI + JetBrainsMono code (unchanged from app);
  weights `displayWeight w700, titleWeight w600, bodyWeight w400`.
- **panelBox**: rounded, thin border, soft blurred drop shadow (alpha ~0.30 dark
  / ~0.10 light) — honors `color`/`borderWidth`/`borderRadius` params.
- **tabShape**: active = surface bg + purple top accent line + no bottom rule;
  hover = subtle selection-color tint; inactive = scaffold bg.
- **scaffoldBackground**: passthrough.
- **wrapInteractive**: `DraculaPress` — scale to 0.98 on press, ~120ms ease.
- **AppCopy**: `emptyResponse: 'SEND A REQUEST TO SEE THE RESPONSE'`.

## Done-bar

`fvm flutter analyze` · `fvm dart run custom_lint` ·
`fvm dart run bloc_tools:bloc lint lib` · `fvm dart format` ·
`fvm flutter test` — all clean/green.
