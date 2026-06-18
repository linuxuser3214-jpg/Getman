import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/storage/hive_boxes.dart';
import 'package:getman/features/tabs/data/datasources/tabs_local_data_source.dart';
import 'package:getman/features/tabs/data/models/panel_model.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;
  late TabsLocalDataSourceImpl ds;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('getman_panels_ds_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(PanelModelAdapter());
    }
    await Hive.openBox<PanelModel>(HiveBoxes.panels);
    await Hive.openBox<dynamic>(HiveBoxes.tabsMeta);
    ds = TabsLocalDataSourceImpl();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'putPanel + getPanels returns panels ordered by panelOrder meta',
    () async {
      await ds.putPanel(
        PanelModel(
          id: 'p2',
          name: 'B',
          orderedTabIds: ['t2'],
          activeTabId: 't2',
        ),
      );
      await ds.putPanel(
        PanelModel(
          id: 'p1',
          name: 'A',
          orderedTabIds: ['t1'],
          activeTabId: 't1',
        ),
      );
      await ds.savePanelMeta(['p1', 'p2'], 'p1');

      final panels = await ds.getPanels();
      expect(panels.map((p) => p.id), ['p1', 'p2']);
      expect(await ds.getActivePanelId(), 'p1');
    },
  );

  test('deletePanels removes panel models', () async {
    await ds.putPanel(
      PanelModel(id: 'p1', name: 'A', orderedTabIds: ['t1'], activeTabId: 't1'),
    );
    await ds.deletePanels(['p1']);
    expect(await ds.getPanels(), isEmpty);
  });
}
