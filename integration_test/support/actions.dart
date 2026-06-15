import 'package:flutter/widgets.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Reusable interactions for driving Getman in E2E flows. These wrap the stable
/// finders (keys / verbatim labels) so individual flow tests read like a script
/// and survive UI tweaks in one place.

/// Types [url] into the active tab's URL field, replacing whatever was there
/// (e.g. the first-run seed URL).
Future<void> enterUrl(PatrolTester $, String url) async {
  await $(const ValueKey('url_field')).enterText(url);
}

/// Taps SEND **without settling** — the response-pending view shows a
/// continuously-animating shimmer, so settling here would never complete. The
/// caller must wait for the response (e.g. `await waitForStatus($, 200)`).
Future<void> tapSend(PatrolTester $) async {
  await $(const ValueKey('send')).tap(settlePolicy: SettlePolicy.noSettle);
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
}
