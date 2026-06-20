import 'package:auris/auris.dart';
import 'package:flutter/material.dart';
import 'package:getman/core/theme/extensions/app_copy.dart';
import 'package:getman/core/theme/extensions/app_decoration.dart';
import 'package:getman/core/theme/extensions/app_layout.dart';
import 'package:getman/core/theme/extensions/app_motion.dart';
import 'package:getman/core/theme/extensions/app_shape.dart';
import 'package:getman/core/theme/extensions/app_typography.dart';
import 'package:getman/core/theme/themes/auris/auris_components.dart';
import 'package:getman/core/theme/themes/auris/auris_decorations.dart';
import 'package:getman/core/theme/themes/auris/auris_motion.dart';
import 'package:getman/core/theme/themes/auris/auris_palette.dart';

/// Builds [ThemeData] for the AURIS theme.
///
/// Uses `AurisTheme.dark` / `AurisTheme.light` as the base so Material
/// component themes already match the auris palette. The five Getman extensions
/// (plus `AppMotion` / [AppCopy] / `AppComponents`) are merged in via
/// `copyWith`, crucially **spreading `base.extensions.values`** first so
/// `AurisScheme` — which every auris widget force-unwraps — is always present.
///
/// Phase D1 wires the AURIS component slots via [aurisComponents].
/// Phase E1 replaces the identity [AppMotion] with `aurisMotion(...)`.
/// Phase E2 replaces [aurisScaffoldBackground] with the real ambient.
ThemeData aurisTheme(
  Brightness brightness, {
  bool isCompact = false,
  bool reduceEffects = false,
}) {
  final base = brightness == Brightness.dark
      ? AurisTheme.dark(glowScale: reduceEffects ? 0.0 : 1.0)
      : AurisTheme.light(glowScale: reduceEffects ? 0.0 : 1.0);

  // AurisTheme attaches AurisScheme automatically — confirmed in C1.
  final scheme = base.extension<AurisScheme>()!;

  final layout = isCompact ? AppLayout.compact : AppLayout.normal;

  const shape = AppShape(
    panelRadius: 3,
    buttonRadius: 3,
    inputRadius: 3,
    dialogRadius: 4,
    sheetRadius: 6,
  );

  final palette = aurisPalette(scheme);

  final typography = AppTypography(
    base: base.textTheme, // Rajdhani/ExoTwo already applied by AurisTheme
    codeFontFamily: AurisTokens.fontMono, // 'packages/auris/ShareTechMono'
    displayWeight: FontWeight.w700,
    titleWeight: FontWeight.w600,
    bodyWeight: FontWeight.w400,
  );

  final decoration = AppDecoration(
    panelBox: aurisPanelBox,
    tabShape: aurisTabShape,
    // Identity for now — Phase E2 replaces with the auris press animation.
    wrapInteractive: ({required child, onTap, scaleDown}) => child,
    // Identity for now — Phase E2 replaces with the scanline/glow ambient.
    scaffoldBackground: aurisScaffoldBackground,
  );

  return base.copyWith(
    // CRITICAL: spread base extensions FIRST so AurisScheme is preserved.
    // Every auris widget calls Theme.of(context).extension<AurisScheme>()!
    // and will throw if this extension is missing.
    // Cast needed: base.extensions.values is Iterable<ThemeExtension<dynamic>>
    // but the list literal infers ThemeExtension<Object?>, which is compatible
    // after the explicit cast below.
    extensions: [
      ...base.extensions.values,
      layout,
      palette,
      shape,
      typography,
      decoration,
      // AURIS HUD motion (Phase E1).
      aurisMotion(reduceEffects: reduceEffects),
      const AppCopy(emptyResponse: '// NO SIGNAL'),
      // AURIS component slots: each surface maps to its Auris* widget.
      aurisComponents(),
    ],
  );
}
