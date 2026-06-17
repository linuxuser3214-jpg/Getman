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

  testWidgets(
    'a reduced-mode press survives mount + dispose (the resize crash)',
    (tester) async {
      // In reduced mode build() never touches the controller, so a lazily
      // `late`-initialized controller would first-initialize inside dispose()
      // — an unsafe TickerMode ancestor lookup on a deactivated element. The
      // controller must be built in initState so dispose just disposes it.
      await tester.pumpWidget(host(animate: false));
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(GlassPress), findsNothing);
    },
  );

  testWidgets(
    'survives a full->reduced->full round trip (the real toggle path)',
    (tester) async {
      // The app boots at animate:true (reduceEffects defaults false). Toggling
      // the setting twice is true -> false -> true. A SingleTickerProvider only
      // allows one ticker for the State's lifetime, so recreating the
      // controller on the second flip used to throw "multiple tickers".
      await tester.pumpWidget(host(animate: true));
      await tester.pumpWidget(host(animate: false));
      await tester.pumpWidget(host(animate: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(GlassPress), findsOneWidget);
    },
  );
}
