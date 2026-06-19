import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/theme/theme_ids.dart';
import 'package:getman/core/theme/theme_registry.dart';
import 'package:getman/core/theme/themes/classic/classic_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('classicTheme', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (final c in [false, true]) {
        for (final r in [false, true]) {
          testWidgets(
            'attaches all six extensions (brightness=$b compact=$c reduce=$r)',
            (tester) async {
              final theme = classicTheme(b, isCompact: c, reduceEffects: r);
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

    test('is registered with the CLASSIC display name', () {
      expect(appThemes[kClassicThemeId], isNotNull);
      expect(appThemes[kClassicThemeId]!.displayName, 'CLASSIC');
      expect(appThemes[kClassicThemeId]!.id, kClassicThemeId);
    });

    testWidgets('panels are soft cards: rounded, soft shadow, no hard offset', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: classicTheme(Brightness.light),
          home: Builder(
            builder: (ctx) {
              final deco = ctx.appDecoration;
              final box = deco.panelBox(ctx);
              expect(box.borderRadius, isNotNull);
              expect(box.boxShadow, isNotEmpty);
              // No branded-tab indicator override → keeps the default filled
              // look.
              expect(deco.brandedTabIndicator, isNull);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('active tab shows an accent bottom indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: classicTheme(Brightness.light),
          home: Builder(
            builder: (ctx) {
              final deco = ctx.appDecoration;
              final active = deco.tabShape(
                ctx,
                active: true,
                hovered: false,
                isFirst: true,
              );
              expect(
                active.border?.bottom.color,
                Theme.of(ctx).colorScheme.primary,
              );
              final inactive = deco.tabShape(
                ctx,
                active: false,
                hovered: false,
                isFirst: false,
              );
              expect(inactive.color, Colors.transparent);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
