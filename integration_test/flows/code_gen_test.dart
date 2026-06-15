import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/app_harness.dart';

/// Flow: open "Generate code" and confirm the default cURL snippet reflects the
/// configured method and URL.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('generates a cURL snippet for the request', ($) async {
    await bootGetman($);

    // Use the seeded GET https://httpbin.org/get request as-is.
    await $(const ValueKey('code_export_button')).tap();
    await $.pumpAndSettle();

    final snippet = $.tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('generated_code_text')),
        )
        .data;
    expect(snippet, isNotNull);
    expect(snippet, contains('curl'));
    expect(snippet, contains('https://httpbin.org/get'));
  });
}
