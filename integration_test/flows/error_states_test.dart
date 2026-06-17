import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Error & edge-case responses: non-2xx rendering, cancel in-flight, connection
/// failure (tab must never stay stuck on SENDING), malformed JSON, empty body.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('renders a 404 response', ($) async {
    final server = await MockServer.start(status: 404, json: {'error': 'nope'});
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/missing'));
    await waitForStatus($, 404);
  });

  patrolWidgetTest('renders a 500 response', ($) async {
    final server = await MockServer.start(status: 500, json: {'boom': true});
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/crash'));
    await waitForStatus($, 500);
  });

  patrolWidgetTest('cancel mid-flight returns to SEND with no response', (
    $,
  ) async {
    // Server holds the response open so the request is in-flight long enough to
    // hit CANCEL.
    final server = await MockServer.start(
      delay: const Duration(seconds: 10),
      json: {'ok': true},
    );
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/slow'));

    await $('CANCEL').waitUntilVisible();
    await $(
      const ValueKey('cancel'),
    ).tap(settlePolicy: SettlePolicy.noSettle);
    await pumpFrames($);

    expect($('SEND'), findsWidgets);
    expect($('CANCEL'), findsNothing);
  });

  patrolWidgetTest('a connection failure releases the tab (not stuck)', (
    $,
  ) async {
    // Bind then immediately close a server → its port refuses connections.
    final dead = await MockServer.start();
    final deadUrl = dead.url('/unreachable');
    await dead.close();

    await bootGetman($);
    await sendTo($, deadUrl);

    // The send fails fast; the button must return to SEND (catch-all releases
    // the tab — it must never be stuck on SENDING). Pump past the SEND/CANCEL
    // AnimatedSwitcher transition before asserting CANCEL is gone, and let the
    // error response pane finish building.
    await $('SEND').waitUntilVisible(timeout: const Duration(seconds: 25));
    await pumpFrames($, frames: 16);
    expect($('SEND'), findsWidgets);
    expect($('CANCEL'), findsNothing);
  });

  patrolWidgetTest('malformed JSON body does not crash the viewer', ($) async {
    final server = await MockServer.start(
      responder: (request) {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{ this is ::: not json , , ');
      },
    );
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/bad-json'));
    await waitForStatus($, 200);

    // Prettify on invalid JSON must fall back to raw, not throw. Exercise both
    // toggle segments.
    await $(const ValueKey('body_toggle_RAW')).tap();
    await $.pumpAndSettle();
    await $(const ValueKey('body_toggle_PRETTY')).tap();
    await $.pumpAndSettle();
  });

  patrolWidgetTest('renders a 204 no-content response', ($) async {
    final server = await MockServer.start(
      responder: (request) {
        request.response.statusCode = 204;
      },
    );
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/no-content'));
    await waitForStatus($, 204);
  });
}
