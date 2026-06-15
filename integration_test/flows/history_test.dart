import 'package:flutter/material.dart' show ListTile;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Cross-feature flow: a sent request lands in the HISTORY side panel, and
/// tapping it reopens the request so it can be sent again.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('records a send in history and re-sends it', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);

    final url = server.url('/ping');
    await sendTo($, url);
    await waitForStatus($, 200);
    expect(server.received, hasLength(1));

    // The send shows up in the HISTORY tab of the side menu.
    await openSideMenuTab($, 'HISTORY');
    final historyTile = find.ancestor(
      of: find.text(url),
      matching: find.byType(ListTile),
    );
    expect($(historyTile), findsOneWidget);

    // Re-open it from history (opens a new tab) and send again.
    await $(historyTile).tap();
    await tapSend($);
    await waitForStatus($, 200);

    expect(server.received, hasLength(2));
    expect(server.received.every((r) => r.uri.path == '/ping'), isTrue);
  });
}
