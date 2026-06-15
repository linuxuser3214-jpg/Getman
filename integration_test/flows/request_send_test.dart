import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Flow: type a URL, hit SEND, and get a response back — the core round trip,
/// exercised against a hermetic localhost server (real Dio path, no internet).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('sends a GET and renders the 200 response', ($) async {
    final server = await MockServer.start(
      json: {'message': 'hello from mock'},
    );
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/ping'));
    await waitForStatus($, 200);

    // The app actually hit the server with a GET.
    expect(server.received, hasLength(1));
    expect(server.received.single.method, 'GET');
    expect(server.received.single.uri.path, '/ping');

    // And the response surfaced in the UI (STATUS chip).
    expect($('200'), findsOneWidget);
  });
}
