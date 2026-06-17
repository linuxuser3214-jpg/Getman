import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';

/// Reads the verbatim text of the generated-code snippet in the export dialog.
String _generatedCode(PatrolTester $) {
  final widget = $.tester.widget<SelectableText>(
    find.byKey(const ValueKey('generated_code_text')),
  );
  return widget.data ?? '';
}

/// Flows for the "Generate code" dialog: the snippet must reflect the request
/// as it is RIGHT NOW (edited URL + method + headers), not a stale config
/// captured at build time. (The url_bar's BlocBuilder buildWhen excludes
/// config.url/headers, so a closure capturing `tab.config` goes stale after a
/// URL edit — regression guard for that fix.)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('code export reflects an edited URL', ($) async {
    await bootGetman($);

    // Replace the seed URL (https://httpbin.org/get) with a distinctive one,
    // WITHOUT triggering any rebuild that would refresh the captured config.
    await enterUrl($, 'https://edited.example.com/widgets');

    await $(const ValueKey('code_export_button')).tap();
    await $.pumpAndSettle();

    final code = _generatedCode($);
    expect(
      code,
      contains('edited.example.com/widgets'),
      reason:
          'Generated snippet must use the current URL, not a stale one. '
          'Got:\n$code',
    );
    expect(code, isNot(contains('httpbin.org')));
  });

  patrolWidgetTest('code export reflects method, headers, and target', (
    $,
  ) async {
    await bootGetman($);

    // Method first (this DOES rebuild the url_bar), then URL + header (these do
    // NOT) — so a stale capture would miss the URL and header.
    await setMethod($, 'POST');
    await enterUrl($, 'https://api.codegen.test/v1/orders');
    await openRequestTab($, 'HEADERS');
    await setHeader($, 0, 'X-Trace', 'trace-42');

    await $(const ValueKey('code_export_button')).tap();
    await $.pumpAndSettle();

    // Default target is cURL — must carry the live method, URL and header.
    final curl = _generatedCode($);
    expect(curl, contains('POST'));
    expect(curl, contains('api.codegen.test/v1/orders'));
    expect(curl, contains('X-Trace'));
    expect(curl, contains('trace-42'));

    // Switch the target language; the new snippet must reflect the same live
    // URL (proves the dialog re-renders from the same fresh config).
    await $(const ValueKey('code_gen_target_dropdown')).tap();
    await $('Python — requests').tap();
    await $.pumpAndSettle();

    final python = _generatedCode($);
    expect(python, contains('api.codegen.test/v1/orders'));
    expect(python, contains('requests'));
  });
}
