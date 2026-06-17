import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/request_config_entity.dart';
import 'package:getman/core/theme/theme_registry.dart';
import 'package:getman/features/tabs/domain/entities/panel_entity.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_bloc.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_event.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_state.dart';
import 'package:getman/features/tabs/presentation/widgets/panel_selector.dart';
import 'package:mocktail/mocktail.dart';

class MockTabsBloc extends MockBloc<TabsEvent, TabsState> implements TabsBloc {}

class _FakeTabsEvent extends Fake implements TabsEvent {}

const String _workPanelId = 'p2';

HttpRequestTabEntity _tab(String id) => HttpRequestTabEntity(
  tabId: id,
  config: HttpRequestConfigEntity(id: id),
);

PanelEntity _panel(String id, String name, List<String> tabIds) => PanelEntity(
  id: id,
  name: name,
  tabs: [for (final t in tabIds) _tab(t)],
  activeTabId: tabIds.first,
);

TabsState _twoPanelState() {
  final p1 = _panel('p1', 'Panel 1', ['t1']);
  final work = _panel(_workPanelId, 'Work', ['t2', 't3']);
  return TabsState(panels: [p1, work], activePanelId: 'p1', tabs: p1.tabs);
}

Widget _host(TabsBloc bloc) {
  return MaterialApp(
    theme: resolveTheme('brutalist')(Brightness.light, isCompact: false),
    home: Scaffold(
      body: BlocProvider<TabsBloc>.value(
        value: bloc,
        child: const Align(child: PanelSelector()),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeTabsEvent());
  });

  late MockTabsBloc bloc;

  setUp(() {
    bloc = MockTabsBloc();
    when(() => bloc.state).thenReturn(_twoPanelState());
  });

  testWidgets('shows the active panel name', (tester) async {
    await tester.pumpWidget(_host(bloc));
    expect(find.text('Panel 1'), findsOneWidget);
  });

  testWidgets('shows active panel name and switches on selection', (
    tester,
  ) async {
    await tester.pumpWidget(_host(bloc));
    expect(find.text('Panel 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('panel_selector_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('panel_row_$_workPanelId')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const SetActivePanel(_workPanelId))).called(1);
  });

  testWidgets('new panel footer dispatches AddPanel', (tester) async {
    await tester.pumpWidget(_host(bloc));
    await tester.tap(find.byKey(const ValueKey('panel_selector_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('panel_add_button')));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const AddPanel())).called(1);
  });

  testWidgets('double-tap the name opens rename', (tester) async {
    await tester.pumpWidget(_host(bloc));
    final gesture = find.byKey(const ValueKey('panel_selector_button'));
    await tester.tap(gesture);
    await tester.tap(gesture); // double
    await tester.pumpAndSettle();
    expect(find.text('RENAME PANEL'), findsOneWidget);
  });

  testWidgets('rename dialog dispatches RenamePanel for the active panel', (
    tester,
  ) async {
    await tester.pumpWidget(_host(bloc));
    final gesture = find.byKey(const ValueKey('panel_selector_button'));
    await tester.tap(gesture);
    await tester.tap(gesture); // double
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('name_prompt_field')),
      'Renamed',
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const RenamePanel('p1', 'Renamed'))).called(1);
  });
}
