import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Deep history coverage: search filtering and re-sending an entry as a new
/// tab.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('search filters history entries', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/findme-history'));
    await waitForStatus($, 200);

    await openSideMenuTab($, 'HISTORY');
    expect($(find.textContaining('findme-history')), findsWidgets);

    // A non-matching query empties the list.
    await $(const ValueKey('history_search_field')).enterText('zzz-no-match');
    await $.tester.pump(const Duration(milliseconds: 500)); // debounce
    await $.pumpAndSettle();
    expect($('NO RESULTS FOUND'), findsOneWidget);

    // A matching query brings it back.
    await $(const ValueKey('history_search_field')).enterText('findme');
    await $.tester.pump(const Duration(milliseconds: 500));
    await $.pumpAndSettle();
    expect($('NO RESULTS FOUND'), findsNothing);
  });

  patrolWidgetTest('re-sending from history opens a new tab', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/resend-me'));
    await waitForStatus($, 200);

    // A fresh empty tab so the only on-screen "/resend-me" is the history row.
    await newTab($);
    expect(tabCount($), 2);

    await openSideMenuTab($, 'HISTORY');
    await $(find.textContaining('resend-me').hitTestable()).first.tap();
    await $.pumpAndSettle();

    expect(tabCount($), 3);
  });
}
