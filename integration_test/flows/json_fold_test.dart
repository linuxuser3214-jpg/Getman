import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:re_editor/re_editor.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

// Flow: a JSON response renders in the pretty (code-editor) viewer with the
// collapse/expand fold gutter wired in. Guards the JSON-folding feature end to
// end in the real app — the gutter indicator (`DefaultCodeChunkIndicator`) must
// be present so object/array regions get fold chevrons.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('JSON response shows the fold gutter', ($) async {
    final server = await MockServer.start(
      json: {
        'user': {'id': 1, 'name': 'ada'},
        'roles': ['admin', 'dev'],
      },
    );
    addTearDown(server.close);

    await bootGetman($);
    await sendTo($, server.url('/profile'));
    await waitForStatus($, 200);

    // The pretty viewer's gutter carries re_editor's fold indicator, so the
    // chevrons are available to collapse the nested object/array.
    expect($(DefaultCodeChunkIndicator), findsAtLeastNWidgets(1));
  });
}
