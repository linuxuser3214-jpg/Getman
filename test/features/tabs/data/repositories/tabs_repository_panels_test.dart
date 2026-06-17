import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/request_config_entity.dart';
import 'package:getman/core/network/network_service.dart';
import 'package:getman/features/history/data/models/request_config_model.dart';
import 'package:getman/features/tabs/data/datasources/tabs_local_data_source.dart';
import 'package:getman/features/tabs/data/models/panel_model.dart';
import 'package:getman/features/tabs/data/models/request_tab_model.dart';
import 'package:getman/features/tabs/data/repositories/tabs_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements TabsLocalDataSource {}

class _MockNet extends Mock implements NetworkService {}

void main() {
  late _MockDs ds;
  late TabsRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = TabsRepositoryImpl(
      localDataSource: ds,
      networkService: _MockNet(),
    );
  });

  test('getPanels migrates existing tabs into one "Panel 1" '
      'when panels box empty', () async {
    when(() => ds.getTabs()).thenAnswer(
      (_) async => [
        HttpRequestTabModel(
          config: HttpRequestConfig.fromEntity(
            const HttpRequestConfigEntity(id: 't1'),
          ),
          tabId: 't1',
        ),
        HttpRequestTabModel(
          config: HttpRequestConfig.fromEntity(
            const HttpRequestConfigEntity(id: 't2'),
          ),
          tabId: 't2',
        ),
      ],
    );
    when(() => ds.getPanels()).thenAnswer((_) async => <PanelModel>[]);

    final panels = await repo.getPanels();
    expect(panels.length, 1);
    expect(panels.single.name, 'Panel 1');
    expect(panels.single.tabs.map((t) => t.tabId), ['t1', 't2']);
    expect(panels.single.activeTabId, 't1');
  });

  test(
    'getPanels returns empty when nothing persisted (true first run)',
    () async {
      when(() => ds.getTabs()).thenAnswer((_) async => []);
      when(() => ds.getPanels()).thenAnswer((_) async => []);
      expect(await repo.getPanels(), isEmpty);
    },
  );

  test('getPanels reconstructs persisted panels from tab models', () async {
    when(() => ds.getTabs()).thenAnswer(
      (_) async => [
        HttpRequestTabModel(
          config: HttpRequestConfig.fromEntity(
            const HttpRequestConfigEntity(id: 't1'),
          ),
          tabId: 't1',
        ),
      ],
    );
    when(() => ds.getPanels()).thenAnswer(
      (_) async => [
        PanelModel(
          id: 'p1',
          name: 'Work',
          orderedTabIds: ['t1'],
          activeTabId: 't1',
        ),
      ],
    );
    final panels = await repo.getPanels();
    expect(panels.single.name, 'Work');
    expect(panels.single.tabs.single.tabId, 't1');
  });
}
