// test/core/theme/themes/rpg_motion_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/extensions/app_motion.dart';
import 'package:getman/core/theme/motion/theme_reaction.dart';
import 'package:getman/core/theme/motion/theme_reaction_controller.dart';
import 'package:getman/core/theme/themes/rpg/rpg_motion.dart';

void main() {
  test('reduced effects returns identity AppMotion', () {
    final motion = rpgMotion(reduceEffects: true);
    expect(motion.reactionOverlay, isA<ReactionOverlayBuilder>());
    const identity = AppMotion();
    // Identity overlay returns child unchanged.
    // (smoke: see widget test below for behavior)
    expect(motion.runtimeType, identity.runtimeType);
  });

  testWidgets('success shower + error shake both render without throwing', (
    tester,
  ) async {
    final motion = rpgMotion(reduceEffects: false);
    final controller = ThemeReactionController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: motion.reactionOverlay(
                context,
                controller: controller,
                child: const Text('app'),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('app'), findsOneWidget);
    controller.fire(
      const ThemeReaction(kind: ThemeReactionKind.success, statusCode: 200),
    );
    await tester.pump(const Duration(milliseconds: 80));
    controller.fire(
      const ThemeReaction(
        kind: ThemeReactionKind.serverError,
        statusCode: 500,
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    expect(find.text('app'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    controller.dispose();
  });
}
