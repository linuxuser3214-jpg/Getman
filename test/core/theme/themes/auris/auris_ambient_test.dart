// test/core/theme/themes/auris/auris_ambient_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/theme/theme_ids.dart';
import 'package:getman/core/theme/theme_registry.dart';
import 'package:getman/core/theme/themes/auris/auris_decorations.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ---------------------------------------------------------------------------
  // Animated scaffold background
  // ---------------------------------------------------------------------------

  testWidgets(
    'AURIS animated scaffold background renders child + pumps without throwing',
    (tester) async {
      final theme = resolveThemeData(
        kAurisThemeId,
        Brightness.dark,
        isCompact: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => context.appDecoration.scaffoldBackground(
              context,
              child: const Text('APP'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('APP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AURIS animated scaffold disposes cleanly (no ticker-after-dispose)',
    (tester) async {
      final theme = resolveThemeData(
        kAurisThemeId,
        Brightness.dark,
        isCompact: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => context.appDecoration.scaffoldBackground(
              context,
              child: const Text('APP'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Replace with empty widget to dispose the State
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // Static (reduceEffects) scaffold background
  // ---------------------------------------------------------------------------

  testWidgets(
    'AURIS static scaffold background builds and settles immediately',
    (tester) async {
      final theme = resolveThemeData(
        kAurisThemeId,
        Brightness.dark,
        isCompact: false,
        reduceEffects: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => context.appDecoration.scaffoldBackground(
              context,
              child: const Text('STATIC'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('STATIC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AURIS static scaffold: aurisStaticScaffoldBackground builds OK',
    (tester) async {
      final theme = resolveThemeData(
        kAurisThemeId,
        Brightness.dark,
        isCompact: false,
        reduceEffects: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => aurisStaticScaffoldBackground(
              context,
              child: const Text('S'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('S'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // Toggle safety — the never-recreate-ticker invariant
  // ---------------------------------------------------------------------------

  testWidgets(
    'AurisWallpaper survives animate:true->false->true round-trip',
    (tester) async {
      final theme = resolveThemeData(
        kAurisThemeId,
        Brightness.dark,
        isCompact: false,
      );

      Widget host({required bool animate}) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AurisWallpaper(animate: animate, child: const Text('T')),
        ),
      );

      await tester.pumpWidget(host(animate: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(host(animate: false));
      await tester.pump();
      await tester.pumpWidget(host(animate: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AurisWallpaper), findsOneWidget);
    },
  );

  testWidgets(
    'AurisWallpaper survives animate:false->true->false round-trip',
    (tester) async {
      final theme = resolveThemeData(
        kAurisThemeId,
        Brightness.dark,
        isCompact: false,
      );

      Widget host({required bool animate}) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AurisWallpaper(animate: animate, child: const Text('T')),
        ),
      );

      await tester.pumpWidget(host(animate: false));
      await tester.pumpWidget(host(animate: true));
      await tester.pumpWidget(host(animate: false));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // AurisPress
  // ---------------------------------------------------------------------------

  testWidgets(
    'AurisPress animate:true fires onTap + no exception',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AurisPress(
              animate: true,
              onTap: () => tapped = true,
              child: const SizedBox(
                width: 40,
                height: 40,
                key: ValueKey<String>('btn'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('btn')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AurisPress animate:false fires onTap + no exception',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AurisPress(
              animate: false,
              onTap: () => tapped = true,
              child: const SizedBox(
                width: 40,
                height: 40,
                key: ValueKey<String>('btn'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('btn')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AurisPress survives animate:true->false->true (no multiple-tickers crash)',
    (tester) async {
      Widget host({required bool animate}) => MaterialApp(
        home: Scaffold(
          body: AurisPress(
            animate: animate,
            onTap: () {},
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );

      await tester.pumpWidget(host(animate: true));
      await tester.pumpWidget(host(animate: false));
      await tester.pumpWidget(host(animate: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AurisPress), findsOneWidget);
    },
  );

  testWidgets(
    'AurisPress reduced mode: mount + dispose without crash',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AurisPress(
              animate: false,
              onTap: () {},
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      // Replace to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
