import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/request_config_entity.dart';
import 'package:getman/features/tabs/data/models/panel_model.dart';
import 'package:getman/features/tabs/domain/entities/panel_entity.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';

HttpRequestTabEntity _tab(String id) => HttpRequestTabEntity(
  tabId: id,
  config: HttpRequestConfigEntity(id: id),
);

void main() {
  test('fromEntity stores only ids; toEntity rebuilds tabs in order', () {
    final entity = PanelEntity(
      id: 'p1',
      name: 'Work',
      tabs: [_tab('t1'), _tab('t2')],
      activeTabId: 't2',
    );
    final model = PanelModel.fromEntity(entity);
    expect(model.orderedTabIds, ['t1', 't2']);
    expect(model.activeTabId, 't2');

    final back = model.toEntity({'t1': _tab('t1'), 't2': _tab('t2')});
    expect(back.tabs.map((t) => t.tabId), ['t1', 't2']);
    expect(back.name, 'Work');
    expect(back.activeTabId, 't2');
  });

  test('toEntity skips ids missing from the map', () {
    final model = PanelModel(
      id: 'p1',
      name: 'A',
      orderedTabIds: ['t1', 'gone', 't2'],
      activeTabId: 't1',
    );
    final back = model.toEntity({'t1': _tab('t1'), 't2': _tab('t2')});
    expect(back.tabs.map((t) => t.tabId), ['t1', 't2']);
  });
}
