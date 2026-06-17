import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';

Future<void> _openPalette(PatrolTester $) async {
  await sendShortcut($, LogicalKeyboardKey.keyK, meta: true);
  expect($(const ValueKey('palette_search_field')), findsOneWidget);
}

Future<void> _typeQuery(PatrolTester $, String q) async {
  await $(const ValueKey('palette_search_field')).enterText(q);
  await $.tester.pump(const Duration(milliseconds: 300)); // debounce (220ms)
  await $.pumpAndSettle();
}

/// Deep command-palette coverage: jump to a saved request, jump to an
/// environment, and arrow-key navigation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('jumps to a saved request (focuses its tab)', ($) async {
    await bootGetman($);

    // Save the seed request (links tab 0; its URL is the httpbin seed).
    await $(const ValueKey('save_request_button')).tap();
    await enterPromptText($, 'PaletteReq');
    await $('SAVE').tap();
    await $.pumpAndSettle();

    // Open an empty tab so the saved request is NOT the active tab.
    await newTab($);
    expect(activeUrl($), isEmpty);

    await _openPalette($);
    await _typeQuery($, 'PaletteReq');
    expect($('PaletteReq'), findsWidgets);
    await $(const ValueKey('palette_result_0')).tap();
    await $.pumpAndSettle();

    // Jumping focuses the existing saved-request tab (AddTab dedupes by node).
    expect(activeUrl($), contains('httpbin'));
  });

  patrolWidgetTest('jumps to an environment (activates it)', ($) async {
    await bootGetman($);

    await openEnvironmentSelector($);
    await $('Manage environments…').tap();
    await $(const ValueKey('new_environment_button')).tap();
    await enterPromptText($, 'PalEnv');
    await $('CREATE').tap();
    await $('CLOSE').tap();
    await $.pumpAndSettle();

    await _openPalette($);
    await _typeQuery($, 'PalEnv');
    await $(const ValueKey('palette_result_0')).tap();
    await $.pumpAndSettle();

    await openEnvironmentSelector($);
    expect($('PalEnv'), findsWidgets);
  });

  patrolWidgetTest('arrow keys navigate and Enter runs a result', ($) async {
    await bootGetman($);

    await _openPalette($);
    await _typeQuery($, 'editorial');
    expect($('EDITORIAL'), findsWidgets);

    // Move selection down then back up, then run it with Enter.
    await sendShortcut($, LogicalKeyboardKey.arrowDown);
    await sendShortcut($, LogicalKeyboardKey.arrowUp);
    await sendShortcut($, LogicalKeyboardKey.enter);
    await $.pumpAndSettle();

    // Running a command closes the palette.
    expect($(const ValueKey('palette_search_field')), findsNothing);
  });
}
