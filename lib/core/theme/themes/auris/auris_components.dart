// AURIS component-slot overrides. Each slot maps an [AppComponents] surface
// onto the matching `Auris*` widget from `package:auris`, so the whole app
// renders in the AURIS HUD aesthetic without touching any feature widget.
//
// Built as `defaultAppComponents().copyWith(...)` so only the overridden slots
// diverge from the shared defaults. Every auris widget force-unwraps
// `Theme.of(context).extension<AurisScheme>()!`; `aurisTheme` guarantees the
// scheme is attached (it spreads `base.extensions.values`), so these closures
// are always called under an AURIS `ThemeData`.
//
// Rules honored: no `data/`/GetIt/BLoC imports; no hardcoded brand colors
// (auris widgets source every color from `AurisScheme`).

import 'dart:async';

import 'package:auris/auris_widgets.dart';
import 'package:flutter/material.dart';
import 'package:getman/core/theme/extensions/app_components.dart';
import 'package:getman/core/theme/extensions/app_components_defaults.dart';

/// Returns the AURIS [AppComponents]: the shared defaults with each surface
/// overridden by its `Auris*` counterpart.
AppComponents aurisComponents() {
  return defaultAppComponents().copyWith(
    surface: _aurisSurface,
    methodBadge: _aurisMethodBadge,
    statusBadge: _aurisStatusBadge,
    metric: _aurisMetric,
    toggle: _aurisToggle,
    logView: _aurisLogView,
    dataRow: _aurisDataRow,
    select: _aurisSelect,
    statusBanner: _aurisStatusBanner,
    pendingIndicator: _aurisPendingIndicator,
  );
}

// ---------------------------------------------------------------------------
// surface
//
// A titled surface becomes a framed [AurisPanel] (header strip + chamfer); an
// untitled surface becomes a bare [AurisContainer]. The four main panels call
// this WITHOUT a title from inside an `Expanded`, so the child must still fill:
// `AurisContainer`'s `DecoratedBox` forwards the (tight) incoming constraints
// to its child, so a fill-wanting child (e.g. a `TabBarView`) fills as before.
// A subtle amber glow is added via `depthSubtle`.
// ---------------------------------------------------------------------------

Widget _aurisSurface(
  BuildContext context, {
  required Widget child,
  String? title,
  String? code,
  bool accent = false,
}) {
  if (title != null) {
    return AurisPanel(title: title, code: code, accent: accent, child: child);
  }
  final scheme = Theme.of(context).extension<AurisScheme>()!;
  return AurisContainer(depth: scheme.depthSubtle, child: child);
}

// ---------------------------------------------------------------------------
// methodBadge / statusBadge  →  AurisBadge (no size param; `small` is ignored)
// ---------------------------------------------------------------------------

AurisBadgeVariant _methodVariant(String method) {
  switch (method.toUpperCase()) {
    case 'GET':
      return AurisBadgeVariant.success;
    case 'POST':
      return AurisBadgeVariant.gold;
    case 'PUT':
      return AurisBadgeVariant.slate;
    case 'PATCH':
      return AurisBadgeVariant.amber;
    case 'DELETE':
      return AurisBadgeVariant.danger;
    default:
      return AurisBadgeVariant.amber;
  }
}

Widget _aurisMethodBadge(
  BuildContext context, {
  required String method,
  bool small = false,
}) {
  return AurisBadge(method, variant: _methodVariant(method));
}

AurisBadgeVariant _statusVariant(int statusCode) {
  if (statusCode >= 200 && statusCode < 300) return AurisBadgeVariant.success;
  if (statusCode >= 300 && statusCode < 400) return AurisBadgeVariant.gold;
  if (statusCode >= 400 && statusCode < 500) return AurisBadgeVariant.amber;
  if (statusCode >= 500 && statusCode < 600) return AurisBadgeVariant.danger;
  return AurisBadgeVariant.amber;
}

Widget _aurisStatusBadge(
  BuildContext context, {
  required int statusCode,
}) {
  return AurisBadge('$statusCode', variant: _statusVariant(statusCode));
}

// ---------------------------------------------------------------------------
// metric
//
// FALLBACK: `AurisStatCard` renders a ~34px value inside a padded
// `AurisContainer` panel — a dashboard tile, not an inline chip. The response
// metadata row is a horizontal `Wrap` of small chips (status / TIME / SIZE), so
// a full stat card overflows/dwarfs the row (confirmed: it overflowed the row
// in the render test). We therefore render a compact auris-styled chip — a
// chamfered `AurisContainer` with the uppercase label + a monospace value,
// intrinsically sized so it sits inline in the `Wrap`. The `delta` (unused by
// the chip) is appended to the value when present so no information is lost.
// The big-tile mapping is kept available behind [kAurisMetricUsesStatCard] for
// any future dashboard context that wants it.
// ---------------------------------------------------------------------------

/// When true, the metric slot renders the large [AurisStatCard]; when false
/// (the default) it renders the compact inline chip suited to the metadata
/// `Wrap`.
const bool kAurisMetricUsesStatCard = false;

Widget _aurisMetric(
  BuildContext context, {
  required String label,
  required String value,
  String? unit,
  String? delta,
}) {
  if (kAurisMetricUsesStatCard) {
    return AurisStatCard(label: label, value: value, unit: unit, delta: delta);
  }
  final scheme = Theme.of(context).extension<AurisScheme>()!;
  final display = <String>[
    if (unit != null) '$value $unit' else value,
    ?delta,
  ].join('  ');
  return AurisContainer(
    fill: scheme.surfaceInset,
    borderColor: scheme.borderBright,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '${label.toUpperCase()} ',
          style: TextStyle(
            fontFamily: AurisTokens.fontBody,
            fontFamilyFallback: AurisTokens.fontBodyFallback,
            fontSize: 11,
            letterSpacing: AurisTokens.trackingLabel,
            color: scheme.textMid,
          ),
        ),
        Text(
          display,
          style: TextStyle(
            fontFamily: AurisTokens.fontMono,
            fontFamilyFallback: AurisTokens.fontMonoFallback,
            fontSize: 13,
            color: scheme.textBright,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// toggle  →  AurisSwitch
// ---------------------------------------------------------------------------

Widget _aurisToggle(
  BuildContext context, {
  required bool value,
  required ValueChanged<bool> onChanged,
  String? label,
}) {
  return AurisSwitch(value: value, onChanged: onChanged, label: label);
}

// ---------------------------------------------------------------------------
// logView  →  AurisTerminal
//
// RISK handled: `AurisTerminal` has a fixed `height` (default 200) — but per
// its API that height is the SCROLLING LOG AREA only; the wrapping `AurisPanel`
// adds its header strip + divider on top, so the widget's TOTAL height is
// `height + chrome`. The realtime log lives in an `Expanded` and should fill,
// so a `LayoutBuilder` passes `height: maxHeight - chrome` (floored) when the
// height is bounded; an unbounded parent keeps the 200 default. Subtracting the
// chrome is what prevents a `RenderFlex` overflow (the panel header would
// otherwise push the total past the available height).
// ---------------------------------------------------------------------------

/// Vertical space the [AurisPanel] header strip + divider add above the
/// terminal log area (header padding 2×11 + ~20px title line + 1px ≈ 44).
const double _kTerminalChrome = 44;

AurisTerminalLineType _lineType(AppLogLineKind kind) {
  switch (kind) {
    case AppLogLineKind.outgoing:
      return AurisTerminalLineType.augment;
    case AppLogLineKind.incoming:
      return AurisTerminalLineType.normal;
    case AppLogLineKind.open:
      return AurisTerminalLineType.ok;
    case AppLogLineKind.close:
      return AurisTerminalLineType.warning;
    case AppLogLineKind.error:
      return AurisTerminalLineType.error;
  }
}

Widget _aurisLogView(
  BuildContext context, {
  required List<AppLogLine> lines,
  String? title,
  ScrollController? controller,
}) {
  final terminalLines = <AurisTerminalLine>[
    for (final l in lines) AurisTerminalLine(l.text, type: _lineType(l.kind)),
  ];
  return LayoutBuilder(
    builder: (context, constraints) {
      final bounded = constraints.hasBoundedHeight;
      // The terminal's `height` sizes only its log area; the panel chrome sits
      // above it. Subtract the chrome from the available height (floored) so
      // the total widget fills its bounded slot without overflowing.
      final logHeight = bounded
          ? (constraints.maxHeight - _kTerminalChrome).clamp(48.0, 100000.0)
          : 200.0;
      return AurisTerminal(
        lines: terminalLines,
        title: title ?? 'LOG',
        height: logHeight,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// dataRow  →  AurisDataRow
// ---------------------------------------------------------------------------

Widget _aurisDataRow(
  BuildContext context, {
  required String label,
  required String value,
  bool highlight = false,
}) {
  return AurisDataRow(label: label, value: value, highlight: highlight);
}

// ---------------------------------------------------------------------------
// select  →  AurisSelect<int> (value = the selected index)
// ---------------------------------------------------------------------------

Widget _aurisSelect(BuildContext context, AppSelectSpec spec) {
  return AurisSelect<int>(
    options: <AurisSelectOption<int>>[
      for (var i = 0; i < spec.items.length; i++)
        AurisSelectOption<int>(value: i, label: spec.items[i].label),
    ],
    value: spec.selectedIndex >= 0 ? spec.selectedIndex : null,
    onChanged: spec.onSelected,
    placeholder: spec.placeholder ?? 'SELECT',
  );
}

// ---------------------------------------------------------------------------
// statusBanner  →  AurisNotification
// (AppBannerState → AurisNotificationVariant, mapped 1:1)
// ---------------------------------------------------------------------------

AurisNotificationVariant _bannerVariant(AppBannerState state) {
  switch (state) {
    case AppBannerState.info:
      return AurisNotificationVariant.info;
    case AppBannerState.success:
      return AurisNotificationVariant.success;
    case AppBannerState.warning:
      return AurisNotificationVariant.warning;
    case AppBannerState.error:
      return AurisNotificationVariant.error;
  }
}

Widget _aurisStatusBanner(
  BuildContext context, {
  required AppBannerState state,
  required String message,
}) {
  return AurisNotification(title: message, variant: _bannerVariant(state));
}

// ---------------------------------------------------------------------------
// pendingIndicator  →  a centered, indeterminate AURIS scan
//
// A single looping AnimationController feeds `AurisProgressBar.animated`; the
// fill sweeps 0→1 and resets, reading as an indeterminate "awaiting signal"
// scan. Centered + padded so it sits in the empty response pane.
// ---------------------------------------------------------------------------

Widget _aurisPendingIndicator(
  BuildContext context, {
  String? label,
}) {
  return _AurisPendingScan(label: label ?? 'AWAITING SIGNAL');
}

class _AurisPendingScan extends StatefulWidget {
  const _AurisPendingScan({required this.label});
  final String label;

  @override
  State<_AurisPendingScan> createState() => _AurisPendingScanState();
}

class _AurisPendingScanState extends State<_AurisPendingScan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => AurisProgressBar.animated(
            value: _controller.value,
            label: widget.label,
          ),
        ),
      ),
    );
  }
}
