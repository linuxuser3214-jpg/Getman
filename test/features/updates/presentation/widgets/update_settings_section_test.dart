import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/features/settings/domain/entities/settings_entity.dart';
import 'package:getman/features/settings/domain/usecases/settings_usecases.dart';
import 'package:getman/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:getman/features/updates/domain/entities/release_info.dart';
import 'package:getman/features/updates/domain/repositories/update_repository.dart';
import 'package:getman/features/updates/presentation/update_controller.dart';
import 'package:getman/features/updates/presentation/widgets/update_settings_section.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _FakeRepo implements UpdateRepository {
  @override
  Future<ReleaseInfo?> fetchLatestRelease(UpdatePlatform p) async => null;
}

class _MockSave extends Mock implements SaveSettingsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const SettingsEntity());
    // UpdateController extends ChangeNotifier; suppress Provider's debug
    // check so RepositoryProvider.value works in tests (Task 12 will wire it
    // via ChangeNotifierProvider app-wide).
    Provider.debugCheckInvalidValueType = null;
  });

  testWidgets('renders toggle + check button and dispatches toggle', (t) async {
    final save = _MockSave();
    when(() => save(any())).thenAnswer((_) async {});
    final bloc = SettingsBloc(saveSettingsUseCase: save);
    final controller = UpdateController(_FakeRepo())
      ..setCurrentVersion('1.0.0');

    await t.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: RepositoryProvider.value(
          value: controller,
          child: BlocProvider.value(
            value: bloc,
            child: const Scaffold(body: UpdateSettingsSection()),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('check_updates_switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('check_updates_button')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('check_updates_switch')));
    await t.pump();
    expect(bloc.state.settings.checkForUpdatesOnStartup, isFalse);
  });
}
