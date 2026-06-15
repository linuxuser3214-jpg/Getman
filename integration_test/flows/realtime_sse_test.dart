import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';
import '../support/mock_ws_server.dart';

/// Flow: switch a request to SSE, connect to a hermetic event-stream endpoint,
/// and see the streamed events arrive in the realtime log.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('connects and receives streamed events (SSE)', ($) async {
    final server = await MockServer.start(
      responder: sseResponder(['event-one', 'event-two']),
    );
    addTearDown(server.close);

    await bootGetman($);

    await setRequestKind($, 'SSE');
    await enterUrl($, server.url('/stream'));

    await $(const ValueKey('realtime_connect_button')).tap();

    // The streamed events land in the log as incoming frames.
    await $('event-one').waitUntilVisible();
    await $('event-two').waitUntilVisible();
  });
}
