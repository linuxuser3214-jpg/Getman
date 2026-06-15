import 'dart:async';

import 'package:flutter/material.dart';

/// Subtle tactile press feedback for the Dracula theme: a quick, gentle
/// scale-down on tap (no overshoot/bounce — Dracula is clean & flat).
///
/// Mirrors the brutalist bounce's structure (a [ScaleTransition] driven by an
/// [AnimationController]) but with a softer default [scaleDown] and an ease-out
/// curve so the interaction reads as a calm depress rather than a bounce.
class DraculaPress extends StatefulWidget {
  const DraculaPress({
    required this.child,
    super.key,
    this.onTap,
    this.scaleDown = 0.98,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<DraculaPress> createState() => _DraculaPressState();
}

class _DraculaPressState extends State<DraculaPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = _buildAnimation();
  }

  Animation<double> _buildAnimation() => Tween<double>(
    begin: 1,
    end: widget.scaleDown,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant DraculaPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleDown != widget.scaleDown) {
      _scaleAnimation = _buildAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        unawaited(_controller.reverse());
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
