import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Flows for the RULES tab (no-code assertions + extractions) and the response
/// TESTS view that reports their results after a send.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('a passing status assertion shows in TESTS', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);

    // Add an assertion: STATUS = 200 (the default target/comparator).
    await openRequestTab($, 'RULES');
    await $('ADD ASSERTION').tap();
    await $(const ValueKey('assertion_expected_0')).enterText('200');

    await sendTo($, server.url('/check'));
    await waitForStatus($, 200);

    await openResponseTab($, 'TESTS');
    expect($('1 / 1 PASSED'), findsOneWidget);
    expect($(find.byIcon(Icons.check_circle_outline)), findsWidgets);
  });

  patrolWidgetTest('a failing status assertion shows in TESTS', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);

    await openRequestTab($, 'RULES');
    await $('ADD ASSERTION').tap();
    // Expect 500, but the server returns 200 → this must fail.
    await $(const ValueKey('assertion_expected_0')).enterText('500');

    await sendTo($, server.url('/check'));
    await waitForStatus($, 200);

    await openResponseTab($, 'TESTS');
    expect($('0 / 1 PASSED'), findsOneWidget);
    expect($(find.byIcon(Icons.cancel_outlined)), findsWidgets);
  });

  patrolWidgetTest('an extraction rule captures a JSON field', ($) async {
    final server = await MockServer.start(json: {'token': 'xyz'});
    addTearDown(server.close);

    await bootGetman($);

    await openRequestTab($, 'RULES');
    await $('ADD EXTRACTION').tap();
    await $(const ValueKey('extraction_expr_0')).enterText(r'$.token');
    await $(const ValueKey('extraction_target_0')).enterText('authToken');

    await sendTo($, server.url('/login'));
    await waitForStatus($, 200);

    await openResponseTab($, 'TESTS');
    expect($('{{authToken}} = xyz'), findsOneWidget);
  });
}
