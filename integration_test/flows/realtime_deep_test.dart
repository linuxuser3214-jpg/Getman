import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';
import '../support/mock_ws_server.dart';

/// Deep realtime coverage: server-initiated WS frames, multiple WS messages,
/// and a multi-event SSE stream.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('renders a server-initiated WS broadcast', ($) async {
    final ws = await MockWebSocketServer.start();
    addTearDown(ws.close);

    await bootGetman($);
    await setRequestKind($, 'WS');
    await enterUrl($, ws.wsUrl);

    await $(const ValueKey('realtime_connect_button')).tap();
    await $('CONNECTED').waitUntilVisible();
    await pumpFrames($);

    // The server pushes an unsolicited frame; it must show as an incoming row.
    ws.broadcast('server-push-1');
    await $('server-push-1').waitUntilVisible();
  });

  patrolWidgetTest('sends and echoes multiple WS messages', ($) async {
    final ws = await MockWebSocketServer.start();
    addTearDown(ws.close);

    await bootGetman($);
    await setRequestKind($, 'WS');
    await enterUrl($, ws.wsUrl);
    await $(const ValueKey('realtime_connect_button')).tap();
    await $('CONNECTED').waitUntilVisible();

    await $(const ValueKey('realtime_message_input')).enterText('first');
    await $(const ValueKey('realtime_send_button')).tap();
    await $('first').waitUntilVisible();

    await $(const ValueKey('realtime_message_input')).enterText('second');
    await $(const ValueKey('realtime_send_button')).tap();
    await $('second').waitUntilVisible();

    expect(ws.received, containsAll(<String>['first', 'second']));
  });

  patrolWidgetTest('streams multiple SSE events', ($) async {
    final server = await MockServer.start(
      responder: sseResponder(['alpha-evt', 'beta-evt', 'gamma-evt']),
    );
    addTearDown(server.close);

    await bootGetman($);
    await setRequestKind($, 'SSE');
    await enterUrl($, server.url('/stream'));
    await $(const ValueKey('realtime_connect_button')).tap();

    await $('alpha-evt').waitUntilVisible();
    await $('beta-evt').waitUntilVisible();
    await $('gamma-evt').waitUntilVisible();
  });
}
