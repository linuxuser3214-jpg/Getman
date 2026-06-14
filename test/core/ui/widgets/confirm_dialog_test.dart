import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/core/ui/widgets/confirm_dialog.dart';

void main() {
  Future<void> pumpOpener(WidgetTester tester, VoidCallback onConfirm) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ConfirmDialog.show(
                context,
                title: 'Delete?',
                message: 'This cannot be undone.',
                onConfirm: onConfirm,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('runs onConfirm only when DELETE is tapped', (tester) async {
    var confirmed = 0;
    await pumpOpener(tester, () => confirmed++);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete?'), findsOneWidget);

    // Cancelling does nothing.
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(confirmed, 0);
    expect(find.text('Delete?'), findsNothing);

    // Confirming runs the callback once.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(confirmed, 1);
    expect(find.text('Delete?'), findsNothing);
  });
}
