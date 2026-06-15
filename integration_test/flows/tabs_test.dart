import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';

/// Counts open request tabs by their per-tab close buttons (`tab_close_<id>`),
/// one per tab — independent of titles.
int _tabCount(PatrolTester $) {
  final finder = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith('tab_close_');
  });
  return $.tester.widgetList(finder).length;
}

/// Flows for the tab strip: opening, closing, and the cURL-paste shortcut that
/// turns a pasted `curl ...` command into a full request.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('opens new tabs and closes one', ($) async {
    await bootGetman($);

    // First run seeds exactly one tab.
    expect(_tabCount($), 1);

    await newTab($);
    expect(_tabCount($), 2);

    await newTab($);
    expect(_tabCount($), 3);

    // Close the newest tab (empty, not dirty → no unsaved-changes prompt).
    final closeButtons = find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('tab_close_');
    });
    await $(closeButtons).last.tap();
    expect(_tabCount($), 2);
  });

  patrolWidgetTest('pasting a cURL command fills the request', ($) async {
    await bootGetman($);

    await enterUrl(
      $,
      'curl -X POST https://api.example.com/users '
      "-H 'X-Token: abc123' -d '{\"name\":\"ada\"}'",
    );
    await $.pumpAndSettle();

    // The URL is parsed out of the cURL command...
    expect($(const ValueKey('url_field')), findsOneWidget);
    expect($('https://api.example.com/users'), findsOneWidget);
    // ...and the method becomes POST (shown in the method selector badge).
    expect($('POST'), findsWidgets);
  });
}
