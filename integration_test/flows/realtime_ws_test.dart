import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_ws_server.dart';

/// Flow: switch a request to WS, connect to a hermetic echo server, send a
/// message, see the echo arrive, and disconnect.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('connects, sends, echoes, and disconnects (WS)', ($) async {
    final ws = await MockWebSocketServer.start();
    addTearDown(ws.close);

    await bootGetman($);

    await setRequestKind($, 'WS');
    await enterUrl($, ws.wsUrl);

    // Connect.
    await $(const ValueKey('realtime_connect_button')).tap();
    await $('CONNECTED').waitUntilVisible();

    // Send a frame; the echo server bounces it back as an incoming frame.
    await $(const ValueKey('realtime_message_input')).enterText('hello');
    await $(const ValueKey('realtime_send_button')).tap();
    await $('hello').waitUntilVisible();
    expect(ws.received, contains('hello'));

    // Disconnect.
    await $(const ValueKey('realtime_connect_button')).tap();
    await $('DISCONNECTED').waitUntilVisible();
  });
}
