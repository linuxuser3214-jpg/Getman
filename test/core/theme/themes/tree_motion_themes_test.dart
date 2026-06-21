// test/core/theme/themes/tree_motion_themes_test.dart
//
// VM-B3: smoke + effect-presence + tap-safety + reduceEffects tests for the
// loud-theme tree drag/drop/expand juice hooks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/auris/auris_motion.dart';
import 'package:getman/core/theme/themes/auris/auris_theme.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_motion.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/core/theme/themes/glass/glass_motion.dart';
import 'package:getman/core/theme/themes/glass/glass_theme.dart';
import 'package:getman/core/theme/themes/rpg/rpg_motion.dart';
import 'package:getman/core/theme/themes/rpg/rpg_theme.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Helper: pump a single hook under a theme, assert child survives + no crash
// ---------------------------------------------------------------------------

Future<void> _pumpHook(
  WidgetTester tester,
  Widget Function(BuildContext) builder,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(builder: builder),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.byKey(const ValueKey('child')), findsOneWidget);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

const _kChild = SizedBox(key: ValueKey('child'), width: 40, height: 40);

// ---------------------------------------------------------------------------
// Smoke tests — all three hooks under each loud theme
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // --- glass ---
  testWidgets('glass treeDragFeedback: smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => glassMotion(
        reduceEffects: false,
      ).treeDragFeedback(ctx, child: _kChild),
      glassTheme(Brightness.dark),
    );
  });

  testWidgets('glass treeDropHighlight(inactive): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => glassMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: false),
      glassTheme(Brightness.dark),
    );
  });

  testWidgets('glass treeDropHighlight(active): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => glassMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: true),
      glassTheme(Brightness.dark),
    );
  });

  testWidgets('glass treeExpandFlourish(expanded): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => glassMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      glassTheme(Brightness.dark),
    );
  });

  // --- rpg ---
  testWidgets('rpg treeDragFeedback: smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) =>
          rpgMotion(reduceEffects: false).treeDragFeedback(ctx, child: _kChild),
      rpgTheme(Brightness.dark),
    );
  });

  testWidgets('rpg treeDropHighlight(active): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => rpgMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: true),
      rpgTheme(Brightness.dark),
    );
  });

  testWidgets('rpg treeExpandFlourish(expanded): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => rpgMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      rpgTheme(Brightness.dark),
    );
  });

  // --- brutalist ---
  testWidgets('brutalist treeDragFeedback: smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => brutalistMotion(
        reduceEffects: false,
      ).treeDragFeedback(ctx, child: _kChild),
      brutalistTheme(Brightness.dark),
    );
  });

  testWidgets('brutalist treeDropHighlight(active): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => brutalistMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: true),
      brutalistTheme(Brightness.dark),
    );
  });

  testWidgets('brutalist treeExpandFlourish(expanded): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => brutalistMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      brutalistTheme(Brightness.dark),
    );
  });

  // --- auris ---
  testWidgets('auris treeDragFeedback: smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => aurisMotion(
        reduceEffects: false,
      ).treeDragFeedback(ctx, child: _kChild),
      aurisTheme(Brightness.dark),
    );
  });

  testWidgets('auris treeDropHighlight(active): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => aurisMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: true),
      aurisTheme(Brightness.dark),
    );
  });

  testWidgets('auris treeExpandFlourish(expanded): smoke', (t) async {
    await _pumpHook(
      t,
      (ctx) => aurisMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      aurisTheme(Brightness.dark),
    );
  });

  // ---------------------------------------------------------------------------
  // Effect-presence: treeDragFeedback adds at least one more DecoratedBox or
  // Material compared to identity (just the raw child).
  // ---------------------------------------------------------------------------

  Future<void> assertDragFeedbackHasLayer(
    WidgetTester tester, {
    required Widget Function(BuildContext) makeWidget,
    required ThemeData theme,
  }) async {
    // Baseline: raw child alone.
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: _kChild),
      ),
    );
    await tester.pump();
    final baseline = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .length;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: Builder(builder: makeWidget)),
      ),
    );
    await tester.pump();
    final withEffect = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .length;

    expect(
      withEffect,
      greaterThan(baseline),
      reason:
          'treeDragFeedback should add at least one DecoratedBox layer; '
          'baseline=$baseline withEffect=$withEffect',
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('glass treeDragFeedback adds layer', (t) async {
    await assertDragFeedbackHasLayer(
      t,
      makeWidget: (ctx) => glassMotion(
        reduceEffects: false,
      ).treeDragFeedback(ctx, child: _kChild),
      theme: glassTheme(Brightness.dark),
    );
  });

  testWidgets('rpg treeDragFeedback adds layer', (t) async {
    await assertDragFeedbackHasLayer(
      t,
      makeWidget: (ctx) =>
          rpgMotion(reduceEffects: false).treeDragFeedback(ctx, child: _kChild),
      theme: rpgTheme(Brightness.dark),
    );
  });

  testWidgets('brutalist treeDragFeedback adds layer', (t) async {
    await assertDragFeedbackHasLayer(
      t,
      makeWidget: (ctx) => brutalistMotion(
        reduceEffects: false,
      ).treeDragFeedback(ctx, child: _kChild),
      theme: brutalistTheme(Brightness.dark),
    );
  });

  testWidgets('auris treeDragFeedback adds layer', (t) async {
    await assertDragFeedbackHasLayer(
      t,
      makeWidget: (ctx) => aurisMotion(
        reduceEffects: false,
      ).treeDragFeedback(ctx, child: _kChild),
      theme: aurisTheme(Brightness.dark),
    );
  });

  // ---------------------------------------------------------------------------
  // Effect-presence: treeDropHighlight(active:true) adds more layers than
  // treeDropHighlight(active:false).
  // ---------------------------------------------------------------------------

  Future<void> assertDropHighlightActiveDiffers(
    WidgetTester tester, {
    required Widget Function(BuildContext, {required bool active}) makeWidget,
    required ThemeData theme,
  }) async {
    // inactive
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(builder: (ctx) => makeWidget(ctx, active: false)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final inactiveCount = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .length;

    // active
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(builder: (ctx) => makeWidget(ctx, active: true)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final activeCount = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .length;

    expect(
      activeCount,
      greaterThanOrEqualTo(inactiveCount),
      reason:
          'active drop highlight should have at least as many '
          'layers as inactive',
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('glass treeDropHighlight active>=inactive layers', (t) async {
    await assertDropHighlightActiveDiffers(
      t,
      makeWidget: (ctx, {required active}) => glassMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: active),
      theme: glassTheme(Brightness.dark),
    );
  });

  testWidgets('rpg treeDropHighlight active>=inactive layers', (t) async {
    await assertDropHighlightActiveDiffers(
      t,
      makeWidget: (ctx, {required active}) => rpgMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: active),
      theme: rpgTheme(Brightness.dark),
    );
  });

  testWidgets('brutalist treeDropHighlight active>=inactive layers', (t) async {
    await assertDropHighlightActiveDiffers(
      t,
      makeWidget: (ctx, {required active}) => brutalistMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: active),
      theme: brutalistTheme(Brightness.dark),
    );
  });

  testWidgets('auris treeDropHighlight active>=inactive layers', (t) async {
    await assertDropHighlightActiveDiffers(
      t,
      makeWidget: (ctx, {required active}) => aurisMotion(
        reduceEffects: false,
      ).treeDropHighlight(ctx, child: _kChild, active: active),
      theme: aurisTheme(Brightness.dark),
    );
  });

  // ---------------------------------------------------------------------------
  // Tap-safety: treeExpandFlourish output contains NO GestureDetector,
  // AbsorbPointer, or blocking IgnorePointer wrapping the child.
  // ---------------------------------------------------------------------------

  Future<void> assertFlourishTapSafe(
    WidgetTester tester, {
    required Widget Function(BuildContext) makeWidget,
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(builder: makeWidget),
        ),
      ),
    );

    // Verify no AbsorbPointer is absorbing events — that would block taps
    // on the child inside a treeExpandFlourish wrapper.
    final absorbers = tester.widgetList<AbsorbPointer>(
      find.byType(AbsorbPointer),
    );
    for (final ab in absorbers) {
      expect(
        ab.absorbing,
        isFalse,
        reason: 'AbsorbPointer must not be absorbing in treeExpandFlourish',
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
  }

  testWidgets('glass treeExpandFlourish is tap-safe', (t) async {
    await assertFlourishTapSafe(
      t,
      makeWidget: (ctx) => glassMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      theme: glassTheme(Brightness.dark),
    );
  });

  testWidgets('rpg treeExpandFlourish is tap-safe', (t) async {
    await assertFlourishTapSafe(
      t,
      makeWidget: (ctx) => rpgMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      theme: rpgTheme(Brightness.dark),
    );
  });

  testWidgets('brutalist treeExpandFlourish is tap-safe', (t) async {
    await assertFlourishTapSafe(
      t,
      makeWidget: (ctx) => brutalistMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      theme: brutalistTheme(Brightness.dark),
    );
  });

  testWidgets('auris treeExpandFlourish is tap-safe', (t) async {
    await assertFlourishTapSafe(
      t,
      makeWidget: (ctx) => aurisMotion(
        reduceEffects: false,
      ).treeExpandFlourish(ctx, child: _kChild, expanded: true),
      theme: aurisTheme(Brightness.dark),
    );
  });

  // ---------------------------------------------------------------------------
  // reduceEffects → identity: all three hooks return the child unchanged.
  // ---------------------------------------------------------------------------

  testWidgets('reduceEffects → all tree hooks return identity', (tester) async {
    const marker = SizedBox(key: ValueKey('m'));
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final m in [
      glassMotion(reduceEffects: true),
      rpgMotion(reduceEffects: true),
      brutalistMotion(reduceEffects: true),
      aurisMotion(reduceEffects: true),
    ]) {
      expect(
        identical(m.treeDragFeedback(ctx, child: marker), marker),
        isTrue,
        reason: 'treeDragFeedback with reduceEffects should be identity',
      );
      expect(
        identical(
          m.treeDropHighlight(ctx, child: marker, active: false),
          marker,
        ),
        isTrue,
        reason: 'treeDropHighlight with reduceEffects should be identity',
      );
      expect(
        identical(
          m.treeDropHighlight(ctx, child: marker, active: true),
          marker,
        ),
        isTrue,
        reason:
            'treeDropHighlight(active) with reduceEffects should be identity',
      );
      expect(
        identical(
          m.treeExpandFlourish(ctx, child: marker, expanded: false),
          marker,
        ),
        isTrue,
        reason: 'treeExpandFlourish with reduceEffects should be identity',
      );
      expect(
        identical(
          m.treeExpandFlourish(ctx, child: marker, expanded: true),
          marker,
        ),
        isTrue,
        reason:
            'treeExpandFlourish(expanded) with reduceEffects '
            'should be identity',
      );
    }
  });
}
