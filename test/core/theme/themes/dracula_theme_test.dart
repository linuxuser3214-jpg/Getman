import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/theme/themes/dracula/dracula_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Disable network font fetching in tests to prevent async errors after
    // tests complete; fonts fall back to system defaults.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('draculaTheme', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (final c in [false, true]) {
        // testWidgets is used (rather than bare test) so the Flutter test zone
        // absorbs the asynchronous google_fonts font-not-found error that fires
        // after assertions pass when fonts are missing from test assets.
        testWidgets(
          'attaches all six extensions for brightness=$b isCompact=$c',
          (tester) async {
            final theme = draculaTheme(b, isCompact: c);
            expect(theme.extension<AppLayout>(), isNotNull);
            expect(theme.extension<AppPalette>(), isNotNull);
            expect(theme.extension<AppShape>(), isNotNull);
            expect(theme.extension<AppTypography>(), isNotNull);
            expect(theme.extension<AppDecoration>(), isNotNull);
            expect(theme.extension<AppCopy>(), isNotNull);
            expect(theme.extension<AppLayout>()!.isCompact, c);
            expect(theme.brightness, b);
          },
        );
      }
    }

    testWidgets(
      'panelBox returns a BoxDecoration with a soft (blurred) shadow, '
      'not a hard offset',
      (tester) async {
        final theme = draculaTheme(Brightness.dark);
        late BoxDecoration decoration;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (ctx) {
                decoration = ctx.appDecoration.panelBox(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.first.blurRadius, greaterThan(0));
      },
    );

    testWidgets('wrapInteractive returns a widget that scales on tap-down', (
      tester,
    ) async {
      final theme = draculaTheme(Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (ctx) => Align(
              alignment: Alignment.topLeft,
              child: ctx.appDecoration.wrapInteractive(
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  key: ValueKey('target'),
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('target')), findsOneWidget);

      final scaleInAlign = find.descendant(
        of: find.byType(Align),
        matching: find.byType(ScaleTransition),
      );
      expect(scaleInAlign, findsOneWidget);

      final gesture = await tester.press(find.byType(GestureDetector));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final scaleBefore = tester
          .widget<ScaleTransition>(scaleInAlign)
          .scale
          .value;
      expect(scaleBefore, lessThan(1.0));
      await gesture.up();
      await tester.pumpAndSettle();
      final scaleAfter = tester
          .widget<ScaleTransition>(scaleInAlign)
          .scale
          .value;
      expect(scaleAfter, 1.0);
    });
  });
}
