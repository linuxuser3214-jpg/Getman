// test/core/theme/themes/auris/auris_ambient_test.dart
//
// Task 12: the new AURIS HUD ambient (scanning grid + radar sweep), the C1/C2
// foundation. Pumped UNDER the AURIS theme so `AurisScheme` is present and the
// scheme-coloured HUD path is exercised (NOT the null-scheme graceful bail).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/theme_ids.dart';
import 'package:getman/core/theme/theme_registry.dart';
import 'package:getman/core/theme/themes/auris/auris_ambient.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('animated auris ambient paints under AURIS theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemes[kAurisThemeId]!.builder(Brightness.dark),
        home: Builder(
          builder: (context) => aurisScaffoldBackgroundAnimated(
            context,
            child: const Text('app'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('app'), findsOneWidget);
    // The animated ambient paints a HUD layer (a CustomPaint with a painter)
    // behind the child — proves the ambient is mounted, not just the child.
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
    // Survives teardown (controller/notifier disposal) with no exception.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('static auris ambient paints one frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemes[kAurisThemeId]!.builder(Brightness.dark),
        home: Builder(
          builder: (context) =>
              aurisStaticScaffoldBackground(context, child: const Text('app')),
        ),
      ),
    );
    // No pump beyond build: the static variant must render its single frame
    // immediately (no controller driving subsequent frames).
    expect(find.text('app'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
