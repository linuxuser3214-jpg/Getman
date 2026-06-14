import 'package:flutter/material.dart';

/// Wraps [child] in a hover-aware [AnimatedContainer] whose decoration is
/// produced by [decoration]. The child is built by the caller and held stable
/// across hover changes, so entering/leaving rebuilds only this wrapper's
/// container — never the (potentially large) child subtree. Replaces the
/// per-widget `bool _isHovered + setState` boilerplate that rebuilt whole rows
/// on every mouse enter/exit.
class HoverHighlight extends StatefulWidget {
  final Widget child;
  final BoxDecoration Function(bool hovered) decoration;
  final Duration duration;

  const HoverHighlight({
    super.key,
    required this.child,
    required this.decoration,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<HoverHighlight> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: widget.duration,
        decoration: widget.decoration(_hovered),
        child: widget.child,
      ),
    );
  }
}
