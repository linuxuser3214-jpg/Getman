import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/extensions/app_layout.dart';

void main() {
  group('AppLayout.quickListMaxHeight', () {
    test('normal exposes a positive list cap', () {
      expect(AppLayout.normal.quickListMaxHeight, greaterThan(0));
    });

    test('compact is no taller than normal', () {
      expect(
        AppLayout.compact.quickListMaxHeight,
        lessThanOrEqualTo(AppLayout.normal.quickListMaxHeight),
      );
    });

    test('copyWith overrides the cap', () {
      final layout = AppLayout.normal.copyWith(quickListMaxHeight: 123);
      expect(layout.quickListMaxHeight, 123);
    });

    test('lerp moves the cap toward the target', () {
      final a = AppLayout.normal.copyWith(quickListMaxHeight: 100);
      final b = AppLayout.normal.copyWith(quickListMaxHeight: 200);
      final mid = a.lerp(b, 0.5);
      expect(mid.quickListMaxHeight, 150);
    });
  });
}
