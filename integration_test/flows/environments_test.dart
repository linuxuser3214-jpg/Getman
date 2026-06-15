import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Flow: create an environment with a variable, make it active, and confirm a
/// `{{var}}` placeholder is resolved at send time (the mock server sees the
/// substituted value, not the raw token).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('resolves an active-environment variable on send', (
    $,
  ) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);

    // Open the environments manager and create one.
    await openEnvironmentSelector($);
    await $('Manage environments…').tap();
    await $(const ValueKey('new_environment_button')).tap();
    await enterPromptText($, 'Dev');
    await $('CREATE').tap();

    // Add a variable `base` pointing at the mock server, then close the dialog.
    await $(const ValueKey('env_var_key_0')).enterText('base');
    await $(const ValueKey('env_var_val_0')).enterText(server.baseUrl);
    await $('CLOSE').tap();

    // Activate the environment.
    await openEnvironmentSelector($);
    await $('Dev').tap();

    // Send a URL that uses the variable; the server must see the resolved path.
    await sendTo($, '{{base}}/env-test');
    await waitForStatus($, 200);

    expect(server.received, hasLength(1));
    expect(server.received.single.uri.path, '/env-test');
  });
}
