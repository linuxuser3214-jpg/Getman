import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/request_config_entity.dart';
import 'package:getman/features/tabs/domain/entities/panel_entity.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';

HttpRequestTabEntity _tab(String id) => HttpRequestTabEntity(
  tabId: id,
  config: HttpRequestConfigEntity(id: id),
);

void main() {
  group('PanelEntity', () {
    test('equality is value-based over all fields', () {
      final a = PanelEntity(
        id: 'p1',
        name: 'Panel 1',
        tabs: [_tab('t1')],
        activeTabId: 't1',
      );
      final b = PanelEntity(
        id: 'p1',
        name: 'Panel 1',
        tabs: [_tab('t1')],
        activeTabId: 't1',
      );
      expect(a, equals(b));
    });

    test('copyWith replaces only provided fields', () {
      final p = PanelEntity(
        id: 'p1',
        name: 'Panel 1',
        tabs: [_tab('t1')],
        activeTabId: 't1',
      );
      final renamed = p.copyWith(name: 'Work');
      expect(renamed.name, 'Work');
      expect(renamed.id, 'p1');
      expect(renamed.tabs, p.tabs);
      expect(renamed.activeTabId, 't1');
    });

    test('PanelListLookup.byId finds the panel or null', () {
      final list = [
        PanelEntity(id: 'p1', name: 'A', tabs: [_tab('t1')], activeTabId: 't1'),
        PanelEntity(id: 'p2', name: 'B', tabs: [_tab('t2')], activeTabId: 't2'),
      ];
      expect(list.byId('p2')!.name, 'B');
      expect(list.byId('nope'), isNull);
    });
  });
}
