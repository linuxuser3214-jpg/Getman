import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Deep chaining coverage: JSONPath body + header assertions, mixed
/// pass/fail summary, comparator variety, and extraction write-back into the
/// active environment.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('a JSONPath body assertion passes', ($) async {
    final server = await MockServer.start(json: {'name': 'ada', 'age': 36});
    addTearDown(server.close);

    await bootGetman($);
    await openRequestTab($, 'RULES');
    await $('ADD ASSERTION').tap();

    // Target = BODY (JSONPath), comparator '=', path $.name, expected ada.
    await $(const ValueKey('assertion_target_0')).tap();
    await $('BODY (JSONPath)').tap();
    await $(const ValueKey('assertion_path_0')).enterText(r'$.name');
    await $(const ValueKey('assertion_expected_0')).enterText('ada');

    await sendTo($, server.url('/who'));
    await waitForStatus($, 200);

    await openResponseTab($, 'TESTS');
    expect($('1 / 1 PASSED'), findsOneWidget);
  });

  patrolWidgetTest('a contains comparator on the body passes', ($) async {
    final server = await MockServer.start(json: {'msg': 'hello world'});
    addTearDown(server.close);

    await bootGetman($);
    await openRequestTab($, 'RULES');
    await $('ADD ASSERTION').tap();

    await $(const ValueKey('assertion_target_0')).tap();
    await $('BODY (JSONPath)').tap();
    await $(const ValueKey('assertion_comp_0')).tap();
    await $('contains').tap();
    await $(const ValueKey('assertion_path_0')).enterText(r'$.msg');
    await $(const ValueKey('assertion_expected_0')).enterText('world');

    await sendTo($, server.url('/msg'));
    await waitForStatus($, 200);

    await openResponseTab($, 'TESTS');
    expect($('1 / 1 PASSED'), findsOneWidget);
  });

  patrolWidgetTest('a header exists assertion passes', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await openRequestTab($, 'RULES');
    await $('ADD ASSERTION').tap();

    await $(const ValueKey('assertion_target_0')).tap();
    await $('HEADER').tap();
    await $(const ValueKey('assertion_comp_0')).tap();
    await $('exists').tap();
    await $(const ValueKey('assertion_path_0')).enterText('content-type');

    await sendTo($, server.url('/h'));
    await waitForStatus($, 200);

    await openResponseTab($, 'TESTS');
    expect($('1 / 1 PASSED'), findsOneWidget);
  });

  patrolWidgetTest('mixed assertions report a partial pass count', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await openRequestTab($, 'RULES');

    // Assertion 0: STATUS = 200 (default target/comparator) → passes.
    await $('ADD ASSERTION').tap();
    await $(const ValueKey('assertion_expected_0')).enterText('200');
    // Assertion 1: STATUS = 500 → fails.
    await $('ADD ASSERTION').tap();
    await $(const ValueKey('assertion_expected_1')).enterText('500');

    await sendTo($, server.url('/mixed'));
    await waitForStatus($, 200);

    await openResponseTab($, 'TESTS');
    expect($('1 / 2 PASSED'), findsOneWidget);
  });

  patrolWidgetTest('extraction writes back into the active environment', (
    $,
  ) async {
    final server = await MockServer.start(json: {'token': 'xyz789'});
    addTearDown(server.close);

    await bootGetman($);

    // Create + activate an environment so writeback has a destination.
    await openEnvironmentSelector($);
    await $('Manage environments…').tap();
    await $(const ValueKey('new_environment_button')).tap();
    await enterPromptText($, 'Caps');
    await $('CREATE').tap();
    await $('CLOSE').tap();
    await $.pumpAndSettle();
    await openEnvironmentSelector($);
    await $('Caps').tap();
    await $.pumpAndSettle();

    // Extraction: $.token → authToken.
    await openRequestTab($, 'RULES');
    await $('ADD EXTRACTION').tap();
    await $(const ValueKey('extraction_expr_0')).enterText(r'$.token');
    await $(const ValueKey('extraction_target_0')).enterText('authToken');

    await sendTo($, server.url('/login'));
    await waitForStatus($, 200);

    // Captured-into-environment feedback.
    expect($(find.textContaining('Captured')), findsWidgets);

    // The active environment now carries the captured value.
    await openEnvironmentSelector($);
    await $('Manage environments…').tap();
    await $.pumpAndSettle();
    expect($('authToken'), findsWidgets);
    expect($('xyz789'), findsWidgets);
  });
}
