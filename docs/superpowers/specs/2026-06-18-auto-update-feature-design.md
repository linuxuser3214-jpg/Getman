# Auto-Update Feature — Design Spec

**Date:** 2026-06-18
**Status:** Approved (design); pending implementation plan
**Feature dir:** `lib/features/updates/`

## 1. Goal

Getman should check GitHub Releases **once on startup** for a newer version and,
if one exists, prompt the user to update. The prompt offers **Update now / Skip
this version / Later**. Settings gain a **"Check for updates on startup"** toggle
and a **"Check for updates"** button for a manual, on-demand check. Updates use
the [`updat`](https://pub.dev/packages/updat) package to download and open a real
per-platform **installer** (so the update genuinely replaces the installed app):
macOS `.dmg`, Windows Inno Setup `setup.exe`, Linux `AppImage`.

The app is **unsigned**, so first launch after update triggers the OS guard
(macOS Gatekeeper / Windows SmartScreen). The flow still proceeds; the dialog and
wiki tell the user how to authorize ("right-click → Open" / "More info → Run
anyway").

## 2. How `updat` works (and why the installer artifacts matter)

`updat` is a single reactive `UpdatWidget`: on mount it calls `getLatestVersion()`,
semver-compares to `currentVersion`, and flips an internal `UpdatStatus` to
`available` when newer. On update it downloads `getBinaryUrl()` into the OS
Downloads folder, auto-extracts **`.zip`** archives, then opens the result via the
OS. It exposes `updateChipBuilder` / `updateDialogBuilder` (full custom UI),
`callback(UpdatStatus)`, `getDownloadFileLocation` (override download path), and
`openOnDownload`/`closeOnInstall` flags.

**Key consequence:** `updat` does *not* replace an installed app in place — it
opens whatever `getBinaryUrl` points at. A raw `.app`-in-a-zip just *runs* the new
build from Downloads; the installed copy is untouched, so the user's shortcut keeps
opening the old version. Therefore each platform must ship a real **installer** that
performs an actual install when opened:

| Platform | Artifact | What "open" does |
|---|---|---|
| macOS | `getman-<v>-macos-arm64.dmg` | Mounts; user drags Getman → Applications (classic install) |
| Windows | `getman-<v>-windows-x64-setup.exe` | Inno Setup installer overwrites the install + relaunches |
| Linux | `getman-<v>-linux-x86_64.AppImage` | Portable executable — running the new file *is* the update |

None of these end in `.zip`, so `updat` performs **no extraction** — it downloads
the file and we launch it ourselves (`openOnDownload: false`, see §6).

## 3. Architecture

```
lib/features/updates/
  domain/
    entities/release_info.dart            # {version, changelog, assetUrl}  (pure Dart)
    repositories/update_repository.dart    # Future<ReleaseInfo?> fetchLatestRelease(UpdatePlatform)
  data/
    datasources/github_release_data_source.dart   # ONE GET to releases/latest (dedicated Dio)
    repositories/update_repository_impl.dart
  presentation/
    update_phase.dart                      # web-safe enum (our own, NOT updat's UpdatStatus)
    update_controller.dart                 # shared command bus + cached release (ChangeNotifier)
    update_gate.dart                       # conditional export (io vs stub)
    update_gate_io.dart                    # real updat-driven gate (imports updat + dart:io)
    update_gate_stub.dart                  # web no-op (returns SizedBox.shrink)
    widgets/update_dialog.dart             # themed Update / Skip this version / Later
    widgets/update_settings_section.dart   # toggle + "CHECK FOR UPDATES" button (GENERAL tab)
```

**Web-safety is load-bearing.** `updat` imports `dart:io` and Getman has a web build
target. Only `update_gate_io.dart` may import `updat` / `dart:io`. Everything else
— controller, dialog, settings UI, data source, repository — uses our own
`UpdatePhase` enum (§6) and `dio`, so the web build compiles. `update_gate.dart`
selects the implementation with a conditional import:

```dart
export 'update_gate_stub.dart' if (dart.library.io) 'update_gate_io.dart';
```

### 3.1 Chosen approach

**Approach A — `UpdatWidget` with custom builders.** One invisible `UpdatWidget`
mounted in `MainScreen` (below `MaterialApp` + the router's `Navigator`, the same
reason the command palette lives there — `showDialog` needs `MaterialLocalizations`
and a `Navigator`). Its `updateChipBuilder` returns `SizedBox.shrink()` but
captures `updat`'s action callbacks into the `UpdateController`, which is exposed to
the widget tree via `RepositoryProvider` (the established `UrlFocusRegistry`
pattern). `updat` is used for the version-check state machine + download; **we** own
the per-platform launch (`openOnDownload: false`).

Rejected: **Approach B** (call `updat`'s non-exported `lib/utils/file_handler.dart`
helpers directly — fragile across versions) and **Approach C** (no `updat` — the
user explicitly asked for `updat`).

## 4. Version check (data source)

- One request: `GET https://api.github.com/repos/thiagomiranda3/Getman/releases/latest`.
- Uses a **dedicated `Dio()`** with no app interceptors — the user's configured
  proxy / SSL-verify / cookies must not be able to break or redirect the updater.
- Parses `tag_name` → strip leading `v` → semantic version; `body` → changelog;
  picks the `assets[]` entry whose `name` matches the running platform suffix:
  - macOS → ends with `-macos-arm64.dmg`
  - Windows → ends with `-windows-x64-setup.exe`
  - Linux → ends with `-linux-x86_64.AppImage`
- Returns `null` on **any** failure (offline, GitHub rate-limit [60/hr
  unauthenticated], no matching asset, malformed JSON). A `null` means "stay
  silent" on startup and "couldn't check" on a manual check.
- The result is **cached for the current check cycle** so `updat`'s three callbacks
  (`getLatestVersion`, `getBinaryUrl`, `getChangelog`) trigger only one network call.
- The platform is injected (an `UpdatePlatform` value) so asset-matching is unit
  testable without `dart:io`.

**Current version** comes from `package_info_plus` (`PackageInfo.fromPlatform()`),
which reads the version Flutter injects from `pubspec.yaml` (`1.0.0`) into each
platform bundle — single source of truth that auto-tracks tag bumps. New
dependencies: `updat: ^1.4.0`, `package_info_plus`.

## 5. Settings (persistence + UI)

### 5.1 Hive fields (`SettingsModel`, typeId 0)

- `bool checkForUpdatesOnStartup` — `@HiveField(25, defaultValue: true)`.
- `String? skippedUpdateVersion` — `@HiveField(26)` (nullable; the version the user
  chose "Skip this version" for).

`SettingsEntity` gains both (`copyWith` uses the `_unchanged` sentinel for the
nullable `skippedUpdateVersion`, like `activeEnvironmentId`). Update CLAUDE.md
"next free" 25 → 27 and regenerate the adapter
(`dart run build_runner build --delete-conflicting-outputs`).

### 5.2 Settings events (`SettingsBloc`)

- `UpdateCheckForUpdatesOnStartup(bool enabled)`
- `SetSkippedUpdateVersion(String? version)`

Each persists immediately and emits, exactly like every other `Update*` event (no
`LoadSettings` — settings are seeded at boot).

### 5.3 Settings UI — GENERAL tab (`update_settings_section.dart`)

Rendered **only on desktop** (`!kIsWeb && (Platform.isMacOS || isWindows ||
isLinux)`); hidden on web/mobile. Appended to `_generalTab`:

- A `_switch` "CHECK FOR UPDATES ON STARTUP" (`ValueKey('check_updates_switch')`)
  bound to `UpdateCheckForUpdatesOnStartup`.
- A `_SettingRow` "UPDATES" with the current version as subtitle (e.g. "Getman
  1.0.0") and a trailing `TextButton` "CHECK FOR UPDATES"
  (`ValueKey('check_updates_button')`) → `context.read<UpdateController>().checkNow()`.

`SettingsDialog` already reads tree-level providers (`CookieStore`), so
`context.read<UpdateController>()` resolves from the dialog route.

## 6. Gate, controller, dialog, and launch flow

### 6.1 `UpdatePhase` (web-safe enum)

```dart
enum UpdatePhase { idle, checking, upToDate, available, downloading, readyToInstall, error, dismissed }
```

`update_gate_io.dart` maps `updat`'s `UpdatStatus` → `UpdatePhase`. No other file
references `updat`.

### 6.2 `UpdateController` (ChangeNotifier, web-safe)

- Holds: `currentVersion`, `latestVersion`, `changelog`, `phase`, `manualInFlight`.
- Holds command callbacks captured from the gate's `UpdatWidget` builder:
  `triggerCheck`, `startUpdate`, `dismiss`.
- Caches the `ReleaseInfo` from the last `fetchLatestRelease()`.
- Public API: `Future<ReleaseInfo?> fetchLatestRelease()` (delegates to repo +
  caches); `void checkNow()` (`manualInFlight = true; triggerCheck?.call()`).
- Registered as a lazy singleton in DI (given `UpdateRepository`) and exposed via
  `RepositoryProvider<UpdateController>` in `main.dart`.

### 6.3 `UpdateGate` (`update_gate_io.dart`, mounted in `MainScreen`)

Builds `UpdatWidget(currentVersion, getLatestVersion, getBinaryUrl, getChangelog,
appName: 'getman', openOnDownload: false, callback: _onStatus, updateChipBuilder:
_captureAndHide)`.

- `getLatestVersion`: **gates the network** —
  `if (!manualInFlight && !settings.checkForUpdatesOnStartup) return null;`
  otherwise `fetchLatestRelease()` and return its version. (Returning `null` leaves
  `updat` quietly in `checking`; harmless since the gate renders nothing and a later
  manual `triggerCheck` re-runs the check.)
- `getBinaryUrl` / `getChangelog`: read from the controller's cached `ReleaseInfo`.
- `_captureAndHide`: writes the callbacks + mapped phase into the controller,
  returns `SizedBox.shrink()`.
- `_onStatus(status)` (deferred via post-frame, reads `SettingsBloc`): decides what
  to surface using a **pure function**:

  ```dart
  bool shouldPrompt({required bool autoCheck, required String? latest,
      required String current, required String? skipped, required bool manual}) {
    if (latest == null) return false;
    if (!_isNewer(latest, current)) return false;
    if (manual) return true;
    if (!autoCheck) return false;
    return latest != skipped;
  }
  ```

  - `available` + `shouldPrompt` → show `UpdateDialog`.
  - `upToDate` + `manualInFlight` → "You're on the latest version" snackbar.
  - `error` + `manualInFlight` → "Couldn't check for updates" snackbar.
  - Always clears `manualInFlight` after handling.

### 6.4 `UpdateDialog` (themed, via `ResponsiveDialogScaffold`)

Shows "UPDATE AVAILABLE", "Getman `<latest>` is available (you have `<current>`)",
the changelog (scrollable plain text from the release body), and three actions:

- **SKIP THIS VERSION** → `SettingsBloc.add(SetSkippedUpdateVersion(latest))`, close.
- **LATER** → `controller.dismiss()`, close (re-checks next launch).
- **UPDATE NOW** (primary) → `controller.startUpdate()` (kicks `updat`'s download);
  the dialog listens to the controller and shows a "Downloading…" spinner during
  `downloading`; on `readyToInstall` runs the **platform launcher** (§6.5).

The dialog notes the unsigned-app authorization step for the host platform.

### 6.5 Platform launcher (`dart:io`, only in the io gate)

We control where `updat` saves the file (override `getDownloadFileLocation` → a
known path in Downloads) and launch it ourselves:

- **macOS:** `Process.run('open', [dmgPath])` → mounts the `.dmg`; user drags to
  Applications. App stays open.
- **Windows:** launch `setup.exe` (detached) then `exit(0)` so the installer can
  overwrite the running exe and relaunch.
- **Linux:** `chmod +x` the AppImage, then reveal it in the file manager
  (`xdg-open` its folder) with a snackbar; AppImage is portable, so running the new
  file is the update. App stays open.

On launch failure → `UpdatePhase.error` + a snackbar; the dialog offers retry/close.

## 7. CI release workflow (`.github/workflows/release.yml`)

Triggers, Flutter setup, the web job, and the publish job (`softprops/action-gh-release`,
notes from `CHANGELOG.md`) are unchanged. Replace the **packaging step** of each
desktop job (raw archive → real installer). Existing icons are reused:
`windows/runner/resources/app_icon.ico`, the `.app`'s baked-in icon, `linux/icon.png`.

- **macOS** — stage `getman.app` + a symlink to `/Applications`, then:
  `hdiutil create -volname "Getman" -srcfolder <staging> -ov -format UDZO "getman-${VERSION}-macos-arm64.dmg"`.
- **Windows** — `choco install innosetup -y`; commit `windows/installer.iss` (a
  **stable** `AppId` GUID so updates overwrite the same install; `DefaultDirName`
  `{autopf}\Getman`; `SetupIconFile` the existing `.ico`; bundles
  `build\windows\x64\runner\Release\*`; Start-Menu + optional desktop shortcut;
  `CloseApplications=yes` + an `AppMutex` so re-running the installer over a running
  instance (the §6.5 update flow, after the app calls `exit(0)`) overwrites cleanly;
  `OutputBaseFilename=getman-{#MyAppVersion}-windows-x64-setup`); run
  `iscc /DMyAppVersion=$env:VERSION windows\installer.iss`.
- **Linux** — build an `AppDir` (`AppRun` launching `usr/bin/getman`, a
  `getman.desktop` with `Exec=getman`/`Icon=getman`, `linux/icon.png` as
  `getman.png`, the bundle under `usr/bin/`), fetch `appimagetool-x86_64.AppImage`,
  run it with `--appimage-extract-and-run` (GH runners may lack FUSE) →
  `getman-${VERSION}-linux-x86_64.AppImage`.

Decision: the installers **replace** the raw `.zip`/`.tar.gz` desktop artifacts
(cleaner releases). The web `.zip` stays.

**Verification:** CI is not locally runnable. Validate the three installer steps via
the existing **`workflow_dispatch`** dry-run (builds artifacts, does not publish)
before cutting a real tag.

## 8. Testing (TDD) & done-bar

- **Unit:** `github_release_data_source` JSON parsing + per-platform asset matching
  (inject `UpdatePlatform`, mock Dio); `release_info` mapping; the pure
  `shouldPrompt` / `_isNewer` semver logic (newer, equal, older, skipped, manual,
  auto-off).
- **Bloc:** `SettingsBloc` handles `UpdateCheckForUpdatesOnStartup` +
  `SetSkippedUpdateVersion` (persist + emit), including clearing the skip with
  `null`.
- **Widget:** settings section renders the toggle + button on desktop; the manual
  button calls `UpdateController.checkNow()` (fake controller); `UpdateDialog`
  renders all three actions and reacts to a faked controller phase.
- **Done-bar (all must pass):** `fvm flutter analyze`, `fvm dart run custom_lint`,
  `fvm dart run bloc_tools:bloc lint lib`, `fvm dart format`, `fvm flutter test`.

## 9. Documentation

- **CLAUDE.md:** add `updat` + `package_info_plus` to the tech stack; list the
  `updates` feature in §2 with a short subsection; add the two new `SettingsModel`
  fields to §3 and bump "next free" to 27; note the web conditional-import
  constraint in §6.
- **Wiki** (`Getman.wiki.git`): a new "Auto-update" page (the startup check, the
  Update/Skip/Later prompt, the GENERAL-tab toggle + Check-for-updates button, the
  per-platform install, and the unsigned-app authorization caveat); add it to
  `_Sidebar.md`.

## 10. Out of scope / non-goals

- Code signing / notarization (app remains unsigned; the OS guard is expected).
- Delta/background/silent updates and download progress bars (a simple spinner only;
  `updat`'s download is not streamed).
- In-place self-replacement without an installer (explicitly not chosen).
- Auto-update on web/mobile (feature is desktop-only; web compiles via the stub).
```
