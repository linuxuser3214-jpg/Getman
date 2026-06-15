import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/theme_ids.dart';
import 'package:getman/core/theme/theme_registry.dart';
import 'package:getman/core/ui/widgets/variable_hover_popover.dart';
import 'package:getman/core/utils/variable_resolution_helper.dart';

Future<void> _pump(WidgetTester tester, ResolvedVariable data) {
  return tester.pumpWidget(
    MaterialApp(
      theme: resolveTheme(kBrutalistThemeId)(
        Brightness.light,
        isCompact: false,
      ),
      home: Scaffold(
        body: Center(child: VariableHoverPopover(data: data)),
      ),
    ),
  );
}

void main() {
  testWidgets('resolved variable shows name, value, and source', (
    tester,
  ) async {
    await _pump(
      tester,
      const ResolvedVariable(
        name: 'base_url',
        kind: VariableValueKind.resolved,
        value: 'https://api.example.com',
        environmentName: 'Production',
      ),
    );
    expect(find.text('{{base_url}}'), findsOneWidget);
    expect(find.text('https://api.example.com'), findsOneWidget);
    expect(find.textContaining('Production'), findsOneWidget);
  });

  testWidgets('secret masks value until reveal is toggled', (tester) async {
    await _pump(
      tester,
      const ResolvedVariable(
        name: 'token',
        kind: VariableValueKind.secret,
        value: 'sk-123',
        environmentName: 'Production',
      ),
    );
    expect(find.text('sk-123'), findsNothing);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(find.text('sk-123'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('dynamic variable shows generated-per-request label', (
    tester,
  ) async {
    await _pump(
      tester,
      const ResolvedVariable(
        name: r'$timestamp',
        kind: VariableValueKind.dynamicValue,
        value: '1700000000',
        environmentName: 'Production',
      ),
    );
    expect(find.textContaining('Generated per request'), findsOneWidget);
    expect(find.text('1700000000'), findsOneWidget);
  });

  testWidgets('unresolved with no env shows no-active-environment', (
    tester,
  ) async {
    await _pump(
      tester,
      const ResolvedVariable(name: 'x', kind: VariableValueKind.unresolved),
    );
    expect(find.textContaining('No active environment'), findsOneWidget);
  });

  testWidgets('unresolved with env shows not-defined-in', (tester) async {
    await _pump(
      tester,
      const ResolvedVariable(
        name: 'x',
        kind: VariableValueKind.unresolved,
        environmentName: 'Production',
      ),
    );
    expect(find.textContaining('Not defined in'), findsOneWidget);
    expect(find.textContaining('Production'), findsOneWidget);
  });
}
