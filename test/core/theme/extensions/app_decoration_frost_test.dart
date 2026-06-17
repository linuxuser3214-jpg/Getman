import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('default frost returns the child unchanged (identity)', (
    tester,
  ) async {
    const child = SizedBox(key: ValueKey('frost_child'));
    late Widget result;
    await tester.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: Builder(
          builder: (ctx) {
            result = ctx.appDecoration.frost(ctx, child: child);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(identical(result, child), isTrue);
  });
}
