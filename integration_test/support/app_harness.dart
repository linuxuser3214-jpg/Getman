import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/di/injection_container.dart' as di;
import 'package:getman/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// The flows assume the **desktop** layout — inline side menu + split-pane
/// request/response (so the `reqtab_*` / `resptab_*` / `menutab_*` tab anchors
/// exist and the side-menu buttons are visible). `flutter test`'s default
/// surface is only 800×600 logical (tablet → drawer side menu), so `bootGetman`
/// widens it to a desktop logical width by lowering **only** the device pixel
/// ratio (see below) — never `physicalSize`, which would decouple rendering
/// from the window and strand it on the "Test starting…" stub (you could no
/// longer watch the app run).
///
/// Watch mode is on whenever a slow-motion delay is requested
/// (`--dart-define=E2E_SLOW_MS=<ms>`). A getter (not a const) so the analyzer
/// doesn't fold the default 0 into dead-code warnings.
bool get _watchMode => const int.fromEnvironment('E2E_SLOW_MS') > 0;

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

  // Watch mode: ask the live test binding to render every frame so the OS
  // window shows the app being driven instead of the "Test starting…" stub.
  // Best-effort — desktop live rendering is unreliable; a mobile simulator is
  // the dependable way to actually watch (see README "Watch it run").
  final binding = WidgetsBinding.instance;
  if (_watchMode && binding is LiveTestWidgetsFlutterBinding) {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  }

  // Reach the desktop layout (logical width > 900) by lowering ONLY the device
  // pixel ratio. physicalSize is left at the real window backing, so rendering
  // stays coupled to the window and the app stays visible — unlike overriding
  // physicalSize, which strands the window on "Test starting…".
  final view = $.tester.view;
  view.devicePixelRatio = view.physicalSize.width / 1600.0;
  addTearDown(view.resetDevicePixelRatio);

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
