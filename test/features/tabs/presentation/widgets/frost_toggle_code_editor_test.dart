import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/core/theme/themes/glass/glass_theme.dart';
import 'package:getman/features/tabs/presentation/widgets/json_code_editor.dart';
import 'package:re_editor/re_editor.dart';

/// Mirrors the real request/response panel: a retained
/// [CodeLineEditingController] owned ABOVE a `frost`-wrapped editor, with the
/// theme toggled while the owning State (and thus the controller) survives.
///
/// Glass's frost wraps its child in `RepaintBoundary > ClipRRect >
/// BackdropFilter`; every other theme's frost is the identity. Toggling between
/// them changes the element type at the frost slot, which — without a stable
/// key on the child — tears down and remounts the editor subtree. Because the
/// controller is retained, the remounted editor's `initState` notifies it while
/// the just-deactivated old editor is still subscribed, and re_editor then does
/// an unsafe ancestor lookup on a deactivated element.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final ValueNotifier<bool> glass = ValueNotifier<bool>(true);
  late final CodeLineEditingController controller = createJsonCodeController()
    ..text = '{"hello": "world"}';

  @override
  void dispose() {
    controller.dispose();
    glass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: glass,
      builder: (context, isGlass, _) => MaterialApp(
        theme: isGlass
            ? glassTheme(Brightness.light)
            : brutalistTheme(Brightness.light),
        // Snap the theme so the frost wrapper toggles in the same frame.
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: 200,
                child: ctx.appDecoration.frost(
                  ctx,
                  borderRadius: BorderRadius.circular(ctx.appShape.panelRadius),
                  child: Container(
                    decoration: ctx.appDecoration.panelBox(ctx, offset: 0),
                    child: JsonCodeEditor(controller: controller),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'toggling a frosting theme off and back on does not remount the editor '
    '(no deactivated-ancestor lookup)',
    (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      final state = tester.state<_HarnessState>(find.byType(_Harness));

      // Glass -> Brutalist: frost wrapper removed.
      state.glass.value = false;
      await tester.pumpAndSettle();

      // Brutalist -> Glass: frost wrapper re-added. This is the transition that
      // crashed in the field.
      state.glass.value = true;
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
