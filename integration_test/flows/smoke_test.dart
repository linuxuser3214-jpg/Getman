import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/app_harness.dart';

/// Flow: the app boots on a clean (isolated) profile and reaches its main UI.
/// A first run seeds a sample request (`https://httpbin.org/get`), so the tabs
/// view — not the empty placeholder — is shown.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('boots to the tabs view with the seeded request', (
    $,
  ) async {
    await bootGetman($);

    expect($(const ValueKey('tabs')), findsOneWidget);
    expect($('https://httpbin.org/get'), findsOneWidget);
  });
}
