import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

bool _urlFieldHasFocus(PatrolTester $) {
  final editable = $.tester.widget<EditableText>(
    find
        .descendant(
          of: find.byKey(const ValueKey('url_field')).hitTestable(),
          matching: find.byType(EditableText),
        )
        .hitTestable(),
  );
  return editable.focusNode.hasFocus;
}

/// Global keyboard shortcuts (defined in main.dart's `appShortcuts`, wired in
/// MainScreen/RequestView): new/close tab, jump-to-tab, next/prev, send, save,
/// focus-URL.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('Cmd+N opens tabs, Cmd+W closes the active one', ($) async {
    await bootGetman($);
    expect(tabCount($), 1);

    await sendShortcut($, LogicalKeyboardKey.keyN, meta: true);
    expect(tabCount($), 2);
    await sendShortcut($, LogicalKeyboardKey.keyN, meta: true);
    expect(tabCount($), 3);

    // Newest tab is active and empty (clean) → closes without a prompt.
    await sendShortcut($, LogicalKeyboardKey.keyW, meta: true);
    expect(tabCount($), 2);
  });

  patrolWidgetTest('Cmd+1..3 jump to the tab at that position', ($) async {
    await bootGetman($); // tab 0 = seed (httpbin)
    await sendShortcut($, LogicalKeyboardKey.keyN, meta: true);
    await enterUrl($, 'https://one.test/a');
    await sendShortcut($, LogicalKeyboardKey.keyN, meta: true);
    await enterUrl($, 'https://two.test/b');

    expect(activeUrl($), contains('two.test'));

    await sendShortcut($, LogicalKeyboardKey.digit1, meta: true);
    expect(activeUrl($), contains('httpbin'));

    await sendShortcut($, LogicalKeyboardKey.digit2, meta: true);
    expect(activeUrl($), contains('one.test'));

    await sendShortcut($, LogicalKeyboardKey.digit3, meta: true);
    expect(activeUrl($), contains('two.test'));
  });

  patrolWidgetTest('Ctrl+Tab / Ctrl+Shift+Tab cycle tabs', ($) async {
    await bootGetman($); // tab 0 = seed (httpbin)
    await sendShortcut($, LogicalKeyboardKey.keyN, meta: true);
    await enterUrl($, 'https://t1.test/x'); // tab 1 active

    // Next wraps from index 1 → 0 (httpbin).
    await sendShortcut($, LogicalKeyboardKey.tab, control: true);
    expect(activeUrl($), contains('httpbin'));

    // Prev wraps from index 0 → 1 (t1).
    await sendShortcut($, LogicalKeyboardKey.tab, control: true, shift: true);
    expect(activeUrl($), contains('t1.test'));
  });

  patrolWidgetTest('Cmd+Enter sends the active request', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await enterUrl($, server.url('/via-shortcut'));
    await sendShortcut($, LogicalKeyboardKey.enter, meta: true, settle: false);
    await waitForStatus($, 200);

    expect(server.received, hasLength(1));
    expect(server.received.single.uri.path, '/via-shortcut');
  });

  patrolWidgetTest('Cmd+S opens the save dialog', ($) async {
    await bootGetman($);
    await sendShortcut($, LogicalKeyboardKey.keyS, meta: true);
    expect($('SAVE TO COLLECTION'), findsWidgets);
    await $('CANCEL').tap();
    await $.pumpAndSettle();
  });

  patrolWidgetTest('Cmd+L focuses the URL field', ($) async {
    await bootGetman($);
    // Move focus away first (open + dismiss settings) so the assertion is real.
    await openSettings($);
    await $('CLOSE').tap();
    await $.pumpAndSettle();

    await sendShortcut($, LogicalKeyboardKey.keyL, meta: true);
    expect(_urlFieldHasFocus($), isTrue);
  });
}
