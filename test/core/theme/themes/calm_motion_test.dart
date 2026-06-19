import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/motion/theme_reaction.dart';
import 'package:getman/core/theme/motion/theme_reaction_controller.dart';
import 'package:getman/core/theme/themes/shared/calm_motion.dart';

void main() {
  testWidgets('renders child + survives success/error pulses', (tester) async {
    final motion = calmMotion(reduceEffects: false);
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
    await tester.pump(const Duration(milliseconds: 100));
    controller.fire(
      const ThemeReaction(
        kind: ThemeReactionKind.clientError,
        statusCode: 404,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    controller.dispose();
  });
}
