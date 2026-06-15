import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/app_harness.dart';

/// Flow: the Cmd/Ctrl+K command palette opens, filters, and runs a result.
/// Themes are always available targets, so we jump to one (no setup needed).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('opens via shortcut, filters, and runs a result', (
    $,
  ) async {
    await bootGetman($);

    // Open the palette with the keyboard shortcut (Cmd+K on macOS).
    await $.tester.sendKeyDownEvent(
      LogicalKeyboardKey.metaLeft,
      platform: 'macos',
    );
    await $.tester.sendKeyEvent(LogicalKeyboardKey.keyK, platform: 'macos');
    await $.tester.sendKeyUpEvent(
      LogicalKeyboardKey.metaLeft,
      platform: 'macos',
    );
    await $.pumpAndSettle();

    expect($(const ValueKey('palette_search_field')), findsOneWidget);

    // Filter to the Editorial theme and run the first result.
    await $(const ValueKey('palette_search_field')).enterText('editorial');
    expect($('EDITORIAL'), findsWidgets);
    await $(const ValueKey('palette_result_0')).tap();

    // The palette closes after running a command.
    await $.pumpAndSettle();
    expect($(const ValueKey('palette_search_field')), findsNothing);
  });
}
