import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/motion/theme_reaction.dart';
import 'package:getman/core/theme/motion/theme_reaction_controller.dart';
import 'package:getman/features/home/presentation/widgets/theme_reaction_listener.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_bloc.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_state.dart';
import 'package:provider/provider.dart';

class _FakeTabsBloc extends Cubit<TabsState> implements TabsBloc {
  _FakeTabsBloc() : super(const TabsState());
  void push(TabsState s) => emit(s);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('fires controller once per reactionSeq increase', (tester) async {
    final bloc = _FakeTabsBloc();
    final controller = ThemeReactionController();
    final fired = <ThemeReactionKind>[];
    controller.addListener(() => fired.add(controller.latest!.kind));

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeReactionController>.value(
        value: controller,
        child: BlocProvider<TabsBloc>.value(
          value: bloc,
          child: const MaterialApp(
            home: ThemeReactionListener(child: SizedBox()),
          ),
        ),
      ),
    );

    expect(fired, isEmpty);

    bloc.push(
      const TabsState(
        reactionSeq: 1,
        lastReaction: ThemeReaction(kind: ThemeReactionKind.sendStarted),
      ),
    );
    await tester.pump();
    expect(fired, [ThemeReactionKind.sendStarted]);

    bloc.push(
      const TabsState(
        reactionSeq: 2,
        lastReaction: ThemeReaction(
          kind: ThemeReactionKind.success,
          statusCode: 200,
        ),
      ),
    );
    await tester.pump();
    expect(
      fired,
      [ThemeReactionKind.sendStarted, ThemeReactionKind.success],
    );

    // An emit that doesn't change reactionSeq does NOT re-fire.
    bloc.push(
      const TabsState(
        reactionSeq: 2,
        isLoading: true,
        lastReaction: ThemeReaction(
          kind: ThemeReactionKind.success,
          statusCode: 200,
        ),
      ),
    );
    await tester.pump();
    expect(fired.length, 2);

    await bloc.close();
    controller.dispose();
  });
}
