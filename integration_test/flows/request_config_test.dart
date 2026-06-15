import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Flow: configure a request — method, a query param, and a header — then send
/// it and assert the mock server received exactly what the UI configured.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('sends the configured method, query param & header', (
    $,
  ) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);

    await setMethod($, 'POST');
    await enterUrl($, server.url('/submit'));

    await openRequestTab($, 'PARAMS');
    await setParam($, 0, 'q', 'search');

    await openRequestTab($, 'HEADERS');
    await setHeader($, 0, 'X-Custom', 'val');

    await tapSend($);
    await waitForStatus($, 200);

    expect(server.received, hasLength(1));
    final req = server.received.single;
    expect(req.method, 'POST');
    expect(req.uri.path, '/submit');
    expect(req.uri.queryParameters['q'], 'search');
    // Header names arrive lower-cased from dart:io.
    expect(req.headers['x-custom'], 'val');
  });
}
