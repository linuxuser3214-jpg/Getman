import 'package:flutter/widgets.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Reusable interactions for driving Getman in E2E flows. These wrap the stable
/// finders (keys / verbatim labels) so individual flow tests read like a script
/// and survive UI tweaks in one place.
///
/// **Slow-motion / watch mode:** pass `--dart-define=E2E_SLOW_MS=<ms>` (or use
/// `E2E_SLOW_MS=<ms> bash integration_test/run_macos.sh [flow]`) to insert a
/// real-time pause after each scripted step, so you can watch the macOS app
/// window change state as the flow runs. Defaults to 0 (no pause) so normal /
/// CI runs stay fast. The pause is woven into the helpers below; raw
/// `$(...).tap()` calls inside individual flows don't pause.
/// Slow-motion pause in milliseconds, from `--dart-define=E2E_SLOW_MS=<ms>`.
/// A getter (not a top-level const) so the analyzer doesn't const-fold the
/// default 0 into the [Duration] below and flag it const / redundant — the real
/// value arrives via `--dart-define` at run time.
int get e2eSlowMs => const int.fromEnvironment('E2E_SLOW_MS');

/// Holds the current frame on screen for [e2eSlowMs] of real wall-clock time
/// (integration_test runs on a live binding, so `pump(duration)` actually
/// waits), giving a human a beat to see the step that just happened. No-op when
/// slow mode is off.
Future<void> slowMo(PatrolTester $) async {
  final ms = e2eSlowMs;
  if (ms <= 0) return;
  await $.tester.pump(Duration(milliseconds: ms));
}

/// Types [url] into the active tab's URL field, replacing whatever was there
/// (e.g. the first-run seed URL).
Future<void> enterUrl(PatrolTester $, String url) async {
  await $(const ValueKey('url_field')).enterText(url);
  await slowMo($);
}

/// Taps SEND **without settling** — the response-pending view shows a
/// continuously-animating shimmer, so settling here would never complete. The
/// caller must wait for the response (e.g. `await waitForStatus($, 200)`).
Future<void> tapSend(PatrolTester $) async {
  await $(const ValueKey('send')).tap(settlePolicy: SettlePolicy.noSettle);
  await slowMo($);
}

/// Enters [url] and taps SEND. Does not wait for the response — follow with
/// [waitForStatus].
Future<void> sendTo(PatrolTester $, String url) async {
  await enterUrl($, url);
  await tapSend($);
}

/// Pumps frames (without requiring a settle, so the shimmer can't block it)
/// until the response STATUS chip shows [statusCode].
Future<void> waitForStatus(PatrolTester $, int statusCode) async {
  await $('$statusCode').waitUntilVisible();
  await slowMo($);
}

// ---------------------------------------------------------------------------
// Tab management
// ---------------------------------------------------------------------------

/// Opens a fresh request tab via the "+" button.
Future<void> newTab(PatrolTester $) async {
  await $(const ValueKey('add_tab_button')).tap();
  await slowMo($);
}

// ---------------------------------------------------------------------------
// Request configuration
// ---------------------------------------------------------------------------

/// Selects an HTTP [method] (e.g. `POST`) from the method dropdown.
Future<void> setMethod(PatrolTester $, String method) async {
  await $(const ValueKey('method_selector')).tap();
  await $(method).tap();
  await slowMo($);
}

/// Selects a request [kind] label — `HTTP`, `WS`, or `SSE`.
Future<void> setRequestKind(PatrolTester $, String kind) async {
  await $(const ValueKey('request_kind_selector')).tap();
  await $(kind).tap();
  await slowMo($);
}

/// Taps a request-config sub-tab by its [label] (`PARAMS`/`AUTH`/`HEADERS`/
/// `BODY`/`RULES`).
Future<void> openRequestTab(PatrolTester $, String label) async {
  await $(ValueKey('reqtab_tab_$label')).tap();
  await slowMo($);
}

/// Taps a response sub-tab by its [label] (`BODY`/`HEADERS`/`COOKIES`/`TESTS`).
Future<void> openResponseTab(PatrolTester $, String label) async {
  await $(ValueKey('resptab_tab_$label')).tap();
  await slowMo($);
}

/// Taps a side-menu tab by its [label] (`COLLECTIONS`/`HISTORY`).
Future<void> openSideMenuTab(PatrolTester $, String label) async {
  await $(ValueKey('menutab_tab_$label')).tap();
  await slowMo($);
}

/// Enters a query-param key/value into the params editor row [index].
/// Assumes the PARAMS tab is open.
Future<void> setParam(
  PatrolTester $,
  int index,
  String key,
  String value,
) async {
  await $(ValueKey('param_key_$index')).enterText(key);
  await $(ValueKey('param_val_$index')).enterText(value);
  await slowMo($);
}

/// Enters a header key/value into the headers editor row [index].
/// Assumes the HEADERS tab is open.
Future<void> setHeader(
  PatrolTester $,
  int index,
  String key,
  String value,
) async {
  await $(ValueKey('header_key_$index')).enterText(key);
  await $(ValueKey('header_val_$index')).enterText(value);
  await slowMo($);
}

/// Selects a body type by its chip label (`NONE`/`RAW`/`FORM`/`MULTIPART`/
/// `BINARY`). Assumes the BODY tab is open.
Future<void> setBodyType(PatrolTester $, String label) async {
  await $(ValueKey('bodytype_$label')).tap();
  await slowMo($);
}

// ---------------------------------------------------------------------------
// Dialogs / chrome
// ---------------------------------------------------------------------------

/// Types [text] into the shared single-line name-prompt dialog field.
Future<void> enterPromptText(PatrolTester $, String text) async {
  await $(const ValueKey('name_prompt_field')).enterText(text);
  await slowMo($);
}

/// Opens the Settings dialog from the side-menu header.
Future<void> openSettings(PatrolTester $) async {
  await $(const ValueKey('settings_button')).tap();
  await slowMo($);
}

/// Opens the active-environment selector popup menu.
Future<void> openEnvironmentSelector(PatrolTester $) async {
  await $(const ValueKey('environment_selector')).tap();
  await slowMo($);
}
