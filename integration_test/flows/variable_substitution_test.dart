import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Flow: `{{...}}` variables are resolved at send time, not sent verbatim.
///
/// Uses the dynamic built-in `{{$timestamp}}` (resolves without an active
/// environment), so the flow needs no environment-dialog driving while still
/// exercising the real substitution pipeline. The mock server asserts on the
/// path it actually received.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest(r'resolves {{$timestamp}} in the URL before sending', (
    $,
  ) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    // `\$` keeps the literal `{{$timestamp}}` token in the Dart string.
    await sendTo($, '${server.baseUrl}/items/{{\$timestamp}}');
    await waitForStatus($, 200);

    expect(server.received, hasLength(1));
    final path = server.received.single.uri.path;
    expect(
      path,
      matches(r'^/items/\d+$'),
      reason: r'the {{$timestamp}} token must resolve to digits',
    );
    expect(
      path,
      isNot(contains('{{')),
      reason: 'the variable must not be sent verbatim',
    );
  });
}
