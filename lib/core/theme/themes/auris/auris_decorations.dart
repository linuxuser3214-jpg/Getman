import 'package:auris/auris.dart';
import 'package:flutter/material.dart';
import 'package:getman/core/theme/app_theme.dart';

/// Plain panel box: [AurisScheme.surfacePanel] fill +
/// [AurisScheme.borderResting] hairline + theme panel radius.
/// The `offset` parameter is ignored — auris has no hard brutalist shadow.
BoxDecoration aurisPanelBox(
  BuildContext context, {
  Color? color,
  double? borderWidth,
  double? offset,
  BorderRadius? borderRadius,
}) {
  final scheme = Theme.of(context).extension<AurisScheme>()!;
  final layout = context.appLayout;
  return BoxDecoration(
    color: color ?? scheme.surfacePanel,
    border: Border.all(
      color: scheme.borderResting,
      width: borderWidth ?? layout.borderThin,
    ),
    borderRadius:
        borderRadius ?? BorderRadius.circular(context.appShape.panelRadius),
  );
}

/// Browser-style tab: active = [AurisScheme.surfacePanel] + gold bottom
/// indicator; hovered = [AurisScheme.surfaceInset]; inactive = transparent.
BoxDecoration aurisTabShape(
  BuildContext context, {
  required bool active,
  required bool hovered,
  required bool isFirst,
}) {
  final scheme = Theme.of(context).extension<AurisScheme>()!;
  final layout = context.appLayout;

  final Color bg;
  if (active) {
    bg = scheme.surfacePanel;
  } else if (hovered) {
    bg = scheme.surfaceInset;
  } else {
    bg = Colors.transparent;
  }

  return BoxDecoration(
    color: bg,
    border: Border(
      bottom: BorderSide(
        color: active ? scheme.primaryActive : Colors.transparent,
        width: layout.borderThick,
      ),
    ),
  );
}

/// Placeholder scaffold — identity wrapper. Phase E2 replaces with the real
/// ambient (scanline grid, subtle glow pulse, etc.).
Widget aurisScaffoldBackground(
  BuildContext context, {
  required Widget child,
}) => child;
