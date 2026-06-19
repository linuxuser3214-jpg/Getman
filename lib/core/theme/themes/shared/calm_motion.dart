import 'dart:async';

import 'package:flutter/material.dart';
import 'package:getman/core/theme/extensions/app_motion.dart';
import 'package:getman/core/theme/extensions/app_palette.dart';
import 'package:getman/core/theme/motion/reaction_stage.dart';
import 'package:getman/core/theme/motion/theme_reaction.dart';
import 'package:getman/core/theme/motion/theme_reaction_controller.dart';

/// Restrained reactive motion for the calm themes: a thin status-colored pulse
/// bar that sweeps the top edge on each outcome. No background motion, no
/// shake. Identity when [reduceEffects].
AppMotion calmMotion({required bool reduceEffects}) {
  if (reduceEffects) return const AppMotion();
  return AppMotion(
    reactionOverlay: (context, {required child, required controller}) =>
        _CalmReactionOverlay(controller: controller, child: child),
    // Calm send: keep the existing interactive press; no extra ritual.
  );
}

class _CalmReactionOverlay extends StatefulWidget {
  const _CalmReactionOverlay({required this.controller, required this.child});
  final ThemeReactionController controller;
  final Widget child;

  @override
  State<_CalmReactionOverlay> createState() => _CalmReactionOverlayState();
}

class _CalmReactionOverlayState extends State<_CalmReactionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Color? _color;

  void _onReaction(ThemeReaction r) {
    if (r.kind == ThemeReactionKind.sendStarted) return;
    final palette = Theme.of(context).extension<AppPalette>();
    _color = r.isError
        ? Theme.of(context).colorScheme.error
        : (palette?.statusColor(r.statusCode ?? 200) ??
              Theme.of(context).colorScheme.primary);
    unawaited(_c.forward(from: 0));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReactionStage(
      controller: widget.controller,
      onReaction: _onReaction,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, child) {
                  final color = _color;
                  if (color == null || _c.value == 0 || _c.value == 1) {
                    return const SizedBox.shrink();
                  }
                  // Fade in then out; full-width 3 px bar.
                  final t = _c.value;
                  final a = t < 0.5 ? t * 2 : (1 - t) * 2;
                  return Container(
                    height: 3,
                    color: color.withValues(alpha: a.clamp(0.0, 1.0)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
