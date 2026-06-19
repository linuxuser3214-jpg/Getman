import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getman/core/theme/motion/theme_reaction_controller.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_bloc.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_state.dart';

/// Bridges request-driven [TabsState] reactions into the app-wide
/// [ThemeReactionController], at the widget layer (it holds both), so TabsBloc
/// never depends on a UI controller — the same rule ChainingWriteBackListener
/// follows. Fires exactly once per `reactionSeq` increase.
class ThemeReactionListener extends StatelessWidget {
  const ThemeReactionListener({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TabsBloc, TabsState>(
      listenWhen: (prev, next) =>
          next.reactionSeq != prev.reactionSeq && next.lastReaction != null,
      listener: (context, state) =>
          context.read<ThemeReactionController>().fire(state.lastReaction!),
      child: child,
    );
  }
}
