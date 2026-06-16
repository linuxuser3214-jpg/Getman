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
  AnimationController? _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
      );
      _scale = Tween<double>(begin: 1, end: widget.scaleDown).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOut),
      );
    }
  }

  @override
  void didUpdateWidget(GlassPress old) {
    super.didUpdateWidget(old);
    if (old.animate == widget.animate) return;
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
      );
      _scale = Tween<double>(begin: 1, end: widget.scaleDown).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOut),
      );
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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
    final controller = _controller!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => controller.forward(),
      onTapUp: (_) {
        unawaited(controller.reverse());
        widget.onTap?.call();
      },
      onTapCancel: controller.reverse,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
