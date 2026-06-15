import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/di/injection_container.dart' as di;
import 'package:getman/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Boots the **real** Getman app for an E2E flow and pumps it until settled.
///
/// Isolation: each boot points Hive at a fresh throwaway temp directory (via
/// [di.init]'s `storageDirectoryOverride`), so a test run never reads or wipes
/// the developer's real saved collections/history/settings. Cleanup is
/// registered with [addTearDown], so it runs after the test even on failure:
/// the DI container is reset, all Hive boxes are closed, and the temp dir is
/// deleted.
///
/// Call once at the start of a flow:
/// ```dart
/// patrolWidgetTest('my flow', ($) async {
///   await bootGetman($);
///   // ... drive the app via `$` ...
/// });
/// ```
Future<void> bootGetman(PatrolTester $) async {
  // The app bundles its Google Fonts; forbid runtime fetching so a test never
  // hits the network for a font (matches main.dart).
  GoogleFonts.config.allowRuntimeFetching = false;

  final tempDir = await Directory.systemTemp.createTemp('getman_e2e');
  addTearDown(() async {
    await di.reset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  final settings = await di.init(storageDirectoryOverride: tempDir.path);
  await $.pumpWidgetAndSettle(MyApp(initialSettings: settings));
}
