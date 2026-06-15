import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/ui/widgets/variable_highlight_controller.dart';

void main() {
  testWidgets('hovering a {{var}} token reports the variable name', (
    tester,
  ) async {
    String? hovered;

    void onEnter(String name, Offset _) => hovered = name;
    void onExit() => hovered = null;

    final controller =
        VariableHighlightController(
            text: '{{base_url}}/users',
            variables: const {'base_url': 'https://api.example.com'},
          )
          ..updateColors(resolved: Colors.green, unresolved: Colors.red)
          ..onVariableEnter = onEnter
          ..onVariableExit = onExit;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: TextField(controller: controller),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    final rect = tester.getRect(find.byType(TextField));
    await gesture.moveTo(Offset(rect.left + 20, rect.center.dy));
    await tester.pumpAndSettle();

    expect(
      hovered,
      'base_url',
      reason:
          'A hovered {{var}} must report its name so the URL bar and '
          'params/headers value fields can show the resolved-value popover.',
    );
  });
}
