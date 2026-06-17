// test/core/ui/widgets/variable_autocomplete_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/core/ui/widgets/variable_autocomplete.dart';
import 'package:getman/core/utils/variable_resolution_helper.dart';
import 'package:getman/core/utils/variable_suggestions.dart';

ResolvedVariable _classify(String name) => ResolvedVariable(
  name: name,
  kind: VariableValueKind.resolved,
  value: 'v-$name',
  environmentName: 'Dev',
);

List<VariableSuggestion> _suggest(String q) => buildVariableSuggestions(
  query: q,
  userVariableNames: const ['baseUrl', 'token', 'userId'],
  classify: _classify,
  includeDynamics: false,
);

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });
  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: Scaffold(
          body: VariableAutocomplete(
            controller: controller,
            focusNode: focusNode,
            suggestionsFor: _suggest,
            child: TextField(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
  }

  testWidgets('typing "{{" opens the menu with all suggestions', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '{{');
    await tester.pumpAndSettle();
    expect(find.text('baseUrl'), findsOneWidget);
    expect(find.text('token'), findsOneWidget);
    expect(find.text('userId'), findsOneWidget);
  });

  testWidgets('typing filters the menu', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '{{to');
    await tester.pumpAndSettle();
    expect(find.text('token'), findsOneWidget);
    expect(find.text('baseUrl'), findsNothing);
  });

  testWidgets('Enter inserts the selected suggestion with closing braces', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '{{');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, '{{baseUrl}}');
    expect(controller.selection.baseOffset, '{{baseUrl}}'.length);
  });

  testWidgets('ArrowDown then Enter inserts the second suggestion', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '{{');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, '{{token}}');
  });

  testWidgets('Escape closes the menu and does not reopen on the same text', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '{{');
    await tester.pumpAndSettle();
    expect(find.text('baseUrl'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('baseUrl'), findsNothing);
  });

  testWidgets('tapping a row inserts it', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '{{');
    await tester.pumpAndSettle();
    await tester.tap(find.text('userId'));
    await tester.pumpAndSettle();
    expect(controller.text, '{{userId}}');
  });

  testWidgets('Ctrl+Space opens the menu on an empty field', (tester) async {
    await pump(tester);
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('baseUrl'), findsOneWidget);
  });
}
