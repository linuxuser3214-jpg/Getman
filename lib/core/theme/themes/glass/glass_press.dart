import 'dart:async';

import 'package:flutter/material.dart';

/// Soft Apple-style press feedback: a gentle scale-down on tap.
///
/// When [animate] is false (reduced visual effects) the scale animation is
/// skipped — taps still register, just without motion.
class GlassPress extends StatefulWidget {
  const GlassPress({
    required this.child,
    required this.animate,
    super.key,
    this.onTap,
    this.scaleDown = 0.98,
  });
  final Widget child;
  final bool animate;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<GlassPress> createState() => _GlassPressState();
}

class _GlassPressState extends State<GlassPress>
    with SingleTickerProviderStateMixin {
  // Created once in initState and kept for the State's lifetime. A
  // SingleTickerProvider permits one ticker ever, so we must NOT
  // dispose+recreate this when animate toggles (that threw "multiple tickers").
  // It is built in initState rather than lazily: in reduced mode build() never
  // touches it, and a lazy `late` field would otherwise first-initialize inside
  // dispose() — an unsafe TickerMode ancestor lookup on a deactivated element
  // (the resize crash). When animate is false it just sits idle at 0.
  late final AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = _buildScale();
  }

  Animation<double> _buildScale() => Tween<double>(
    begin: 1,
    end: widget.scaleDown,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(GlassPress old) {
    super.didUpdateWidget(old);
    if (old.scaleDown != widget.scaleDown) _scale = _buildScale();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        unawaited(_controller.reverse());
        widget.onTap?.call();
      },
      onTapCancel: _controller.reverse,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
