import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/theme/themes/glass/glass_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('glassTheme', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (final c in [false, true]) {
        for (final r in [false, true]) {
          testWidgets(
            'attaches all six extensions (brightness=$b compact=$c reduce=$r)',
            (tester) async {
              final theme = glassTheme(b, isCompact: c, reduceEffects: r);
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
    }

    testWidgets('frost wraps in BackdropFilter when effects are full', (
      tester,
    ) async {
      final theme = glassTheme(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (ctx) =>
                ctx.appDecoration.frost(ctx, child: const SizedBox()),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('frost is identity when effects are reduced', (tester) async {
      final theme = glassTheme(Brightness.dark, reduceEffects: true);
      const child = SizedBox(key: ValueKey('c'));
      late Widget result;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (ctx) {
              result = ctx.appDecoration.frost(ctx, child: child);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(identical(result, child), isTrue);
    });
  });
}
