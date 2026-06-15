import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Flow: after a send, the response pane shows the status/time/size metadata,
/// the pretty/raw body toggle, and the response headers.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('shows metadata, body toggle, and headers', ($) async {
    final server = await MockServer.start(json: {'hello': 'world'});
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/data'));
    await waitForStatus($, 200);

    // Metadata row (labels render as "STATUS: ", "TIME: ", "SIZE: ").
    expect($(find.textContaining('STATUS')), findsWidgets);
    expect($(find.textContaining('TIME')), findsWidgets);
    expect($(find.textContaining('SIZE')), findsWidgets);

    // Body view pretty/raw toggle — exercise both segments.
    expect($(const ValueKey('body_toggle_PRETTY')), findsOneWidget);
    await $(const ValueKey('body_toggle_RAW')).tap();
    await $(const ValueKey('body_toggle_PRETTY')).tap();

    // Headers tab lists response headers (keys are upper-cased).
    await openResponseTab($, 'HEADERS');
    expect($(find.textContaining('CONTENT-TYPE')), findsWidgets);
  });
}
