import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Toolchain de-risk: proves the E2E pipeline works end to end before we invest
/// in the real harness — `integration_test` binding + `patrol_finders` (`$`) +
/// the macOS build/run, driven by
/// `fvm flutter test integration_test -d macos`. It pumps a bare widget (no app
/// boot, no Hive), so a failure here points at the toolchain, not the app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('pipeline: pumps a widget and finds text on macOS', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('patrol-pipeline-ok'))),
      ),
    );

    expect($('patrol-pipeline-ok'), findsOneWidget);
  });
}
