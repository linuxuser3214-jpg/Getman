import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Deep request-config coverage: the bulk (paste-many) editor for params and
/// headers.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('bulk-editing params round-trips and sends', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await enterUrl($, server.url('/bulk-params'));
    await openRequestTab($, 'PARAMS');

    // Enter bulk mode and paste two params as "key: value" lines.
    await $(find.text('Bulk edit').hitTestable()).tap();
    await $.pumpAndSettle();
    await $(const ValueKey('param_bulk')).enterText('foo: 1\nbar: 2');
    await $.pumpAndSettle();

    // Back to rows — the parsed rows are present.
    await $(find.text('Edit as rows').hitTestable()).tap();
    await $.pumpAndSettle();
    expect($(find.textContaining('foo')), findsWidgets);

    await tapSend($);
    await waitForStatus($, 200);

    final q = server.received.single.uri.queryParameters;
    expect(q['foo'], '1');
    expect(q['bar'], '2');
  });

  patrolWidgetTest('bulk-editing headers sends both headers', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await enterUrl($, server.url('/bulk-headers'));
    await openRequestTab($, 'HEADERS');

    await $(find.text('Bulk edit').hitTestable()).tap();
    await $.pumpAndSettle();
    await $(
      const ValueKey('header_bulk'),
    ).enterText('X-One: alpha\nX-Two: beta');
    await $.pumpAndSettle();

    await tapSend($);
    await waitForStatus($, 200);

    final headers = server.received.single.headers;
    expect(headers['x-one'], 'alpha');
    expect(headers['x-two'], 'beta');
  });
}
