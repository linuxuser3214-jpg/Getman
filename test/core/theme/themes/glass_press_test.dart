import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/glass/glass_press.dart';

void main() {
  Widget host({required bool animate}) => MaterialApp(
    home: Scaffold(
      body: GlassPress(
        animate: animate,
        onTap: () {},
        child: const SizedBox(width: 40, height: 40),
      ),
    ),
  );

  testWidgets('survives an animate flip reduced->full without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(host(animate: false));
    await tester.pumpWidget(
      host(animate: true),
    ); // rebuilds GlassPress in place
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(GlassPress), findsOneWidget);
  });

  testWidgets('survives an animate flip full->reduced without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(host(animate: true));
    await tester.pumpWidget(host(animate: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
