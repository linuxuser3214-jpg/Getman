import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/features/settings/domain/entities/settings_entity.dart';
import 'package:getman/features/settings/domain/usecases/settings_usecases.dart';
import 'package:getman/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:getman/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockSaveSettings extends Mock implements SaveSettingsUseCase {}

SettingsBloc _bloc() {
  final save = _MockSaveSettings();
  when(() => save(any())).thenAnswer((_) async {});
  return SettingsBloc(
    saveSettingsUseCase: save,
    initialSettings: const SettingsEntity(),
  );
}

Future<void> _open(WidgetTester tester, SettingsBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brutalistTheme(Brightness.light),
      home: BlocProvider.value(
        value: bloc,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SettingsDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(const SettingsEntity()));

  testWidgets('shows four tabs; GENERAL is the default pane', (tester) async {
    final bloc = _bloc();
    addTearDown(bloc.close);
    await _open(tester, bloc);

    expect(
      find.byKey(const ValueKey('settingstab_tab_GENERAL')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settingstab_tab_APPEARANCE')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settingstab_tab_NETWORK')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settingstab_tab_WORKSPACE')),
      findsOneWidget,
    );

    // GENERAL active → history limit visible; APPEARANCE's theme dropdown not.
    expect(find.byKey(const ValueKey('history_limit_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme_dropdown')), findsNothing);
  });

  testWidgets("switching tabs reveals each pane's controls", (tester) async {
    final bloc = _bloc();
    addTearDown(bloc.close);
    await _open(tester, bloc);

    await tester.tap(find.byKey(const ValueKey('settingstab_tab_APPEARANCE')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme_dropdown')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settingstab_tab_NETWORK')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receive_timeout_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('cookies_manage_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settingstab_tab_WORKSPACE')));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE FOLDER'), findsOneWidget);
  });
}
