import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/theme/themes/glass/glass_decorations.dart';
import 'package:getman/core/theme/themes/glass/glass_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('glassFrost wraps its child in a BackdropFilter', (tester) async {
    const child = SizedBox(key: ValueKey('panel'));
    await tester.pumpWidget(
      MaterialApp(
        theme: glassTheme(Brightness.dark),
        home: Builder(
          builder: (ctx) => glassFrost(ctx, child: child),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byKey(const ValueKey('panel')), findsOneWidget);
  });

  testWidgets('glassPanelBox is translucent (alpha < 1)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: glassTheme(Brightness.dark),
        home: Builder(
          builder: (ctx) {
            final box = ctx.appDecoration.panelBox(ctx);
            expect((box.color!.a) < 1.0, isTrue);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('GlassWallpaper survives an animate flip without crashing', (
    tester,
  ) async {
    Widget host({required bool animate}) => MaterialApp(
      theme: glassTheme(Brightness.dark),
      home: GlassWallpaper(animate: animate, child: const SizedBox()),
    );
    await tester.pumpWidget(host(animate: false));
    await tester.pumpWidget(host(animate: true)); // creates the controller
    await tester.pump();
    expect(tester.takeException(), isNull);
    // End on the static variant so didUpdateWidget disposes the controller
    // (avoids a pending-timer error at teardown).
    await tester.pumpWidget(host(animate: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
