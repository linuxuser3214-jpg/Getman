import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/features/updates/presentation/widgets/update_dialog.dart';

void main() {
  testWidgets('renders version line + all three actions', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: Builder(
          builder: (context) => const Scaffold(
            body: UpdateDialog(
              latestVersion: '1.1.0',
              currentVersion: '1.0.0',
              changelog: 'New things',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('1.1.0'), findsWidgets);
    expect(find.byKey(const ValueKey('update_skip_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('update_later_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('update_now_button')), findsOneWidget);
  });
}
