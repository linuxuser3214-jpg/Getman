import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';
import '../support/mock_server.dart';

/// Deep auth coverage beyond bearer: Basic auth and API-key (header + query).
/// The URL is always set BEFORE configuring auth — the url_bar dispatches with
/// a captured tab, so editing the URL afterwards would clobber the auth config.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('basic auth sends an Authorization: Basic header', (
    $,
  ) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await enterUrl($, server.url('/basic'));
    await openRequestTab($, 'AUTH');
    await $(const ValueKey('auth_type_dropdown')).tap();
    await $('BASIC AUTH').tap();
    await $(const ValueKey('auth_field_USERNAME')).enterText('demo');
    await $(const ValueKey('auth_field_PASSWORD')).enterText('pw123');

    await tapSend($);
    await waitForStatus($, 200);

    final expected = 'Basic ${base64Encode(utf8.encode('demo:pw123'))}';
    expect(server.received.single.headers['authorization'], expected);
  });

  patrolWidgetTest('API key is sent as a header', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await enterUrl($, server.url('/apikey-header'));
    await openRequestTab($, 'AUTH');
    await $(const ValueKey('auth_type_dropdown')).tap();
    await $('API KEY').tap();
    await $(const ValueKey('auth_field_KEY')).enterText('X-Api-Key');
    await $(const ValueKey('auth_field_VALUE')).enterText('secret123');

    await tapSend($);
    await waitForStatus($, 200);

    expect(server.received.single.headers['x-api-key'], 'secret123');
  });

  patrolWidgetTest('API key is sent as a query param', ($) async {
    final server = await MockServer.start(json: {'ok': true});
    addTearDown(server.close);

    await bootGetman($);
    await enterUrl($, server.url('/apikey-query'));
    await openRequestTab($, 'AUTH');
    await $(const ValueKey('auth_type_dropdown')).tap();
    await $('API KEY').tap();
    await $(const ValueKey('auth_field_KEY')).enterText('api_key');
    await $(const ValueKey('auth_field_VALUE')).enterText('qval');

    // Switch the "ADD TO" location from HEADER to QUERY PARAM.
    await $('HEADER').tap();
    await $('QUERY PARAM').tap();

    await tapSend($);
    await waitForStatus($, 200);

    expect(server.received.single.uri.queryParameters['api_key'], 'qval');
  });
}
