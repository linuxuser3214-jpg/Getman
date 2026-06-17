import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// First on-screen form-data field for [prefix] (`name` / `val`). Rows are keyed
/// `name_<counter>` / `val_<counter>` (a process-wide counter), so target by
/// prefix rather than a fixed index. Excludes the dialog `name_prompt_field`.
Finder _firstFormField(String prefix) => find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('${prefix}_') &&
      k.value != 'name_prompt_field';
}).hitTestable();

/// Body-type coverage: switching every body type without breaking, sending a
/// urlencoded FORM body, and the RAW beautify button.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('switching body types never breaks the editor', ($) async {
    await bootGetman($);
    await openRequestTab($, 'BODY');

    for (final type in ['RAW', 'FORM', 'MULTIPART', 'BINARY', 'NONE']) {
      await setBodyType($, type);
      expect(
        $(find.byKey(const ValueKey('url_field')).hitTestable()),
        findsOneWidget,
        reason: 'App must stay intact after selecting $type body.',
      );
    }
  });

  patrolWidgetTest('sends a urlencoded FORM body', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await setMethod($, 'POST');
    await enterUrl($, server.url('/form'));
    await openRequestTab($, 'BODY');
    await setBodyType($, 'FORM');

    await $(_firstFormField('name')).first.enterText('alpha');
    await $(_firstFormField('val')).first.enterText('one');
    await $.pumpAndSettle();

    await tapSend($);
    await waitForStatus($, 200);

    final received = server.received.single;
    expect(received.method, 'POST');
    expect(received.body, contains('alpha=one'));
    expect(
      received.headers['content-type'],
      contains('application/x-www-form-urlencoded'),
    );
  });

  patrolWidgetTest('RAW beautify button reports on an empty body', ($) async {
    await bootGetman($);
    await openRequestTab($, 'BODY');
    await setBodyType($, 'RAW');

    // Empty body → beautify reports "already formatted / not valid JSON"
    // rather than crashing.
    await $(find.byIcon(Icons.auto_fix_high)).tap();
    await $.pumpAndSettle();
    expect($(find.textContaining('formatted')), findsWidgets);
  });
}
