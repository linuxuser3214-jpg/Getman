import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Flow: configure Bearer auth and confirm the Authorization header is sent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('bearer token is sent as an Authorization header', (
    $,
  ) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);

    // Set the URL first: the URL bar dispatches with a captured tab, so editing
    // the URL after configuring auth would clobber the auth config.
    await enterUrl($, server.url('/secure'));

    await openRequestTab($, 'AUTH');
    await $(const ValueKey('auth_type_dropdown')).tap();
    await $('BEARER TOKEN').tap();
    await $(const ValueKey('auth_field_TOKEN')).enterText('mytoken123');

    await tapSend($);
    await waitForStatus($, 200);

    expect(server.received, hasLength(1));
    expect(
      server.received.single.headers['authorization'],
      'Bearer mytoken123',
    );
  });
}
