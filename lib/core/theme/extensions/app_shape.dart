import 'package:flutter/material.dart';

class AppShape extends ThemeExtension<AppShape> {
  final double panelRadius;
  final double buttonRadius;
  final double inputRadius;
  final double dialogRadius;

  const AppShape({
    required this.panelRadius,
    required this.buttonRadius,
    required this.inputRadius,
    required this.dialogRadius,
  });

  @override
  AppShape copyWith({
    double? panelRadius,
    double? buttonRadius,
    double? inputRadius,
    double? dialogRadius,
  }) {
    return AppShape(
      panelRadius: panelRadius ?? this.panelRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
    );
  }

  @override
  AppShape lerp(ThemeExtension<AppShape>? other, double t) {
    if (other is! AppShape) return this;
    double l(double a, double b) => (b - a) * t + a;
    return AppShape(
      panelRadius: l(panelRadius, other.panelRadius),
      buttonRadius: l(buttonRadius, other.buttonRadius),
      inputRadius: l(inputRadius, other.inputRadius),
      dialogRadius: l(dialogRadius, other.dialogRadius),
    );
  }
}
