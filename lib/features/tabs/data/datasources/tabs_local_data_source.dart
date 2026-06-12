import 'package:getman/core/error/exceptions.dart';
import 'package:getman/core/storage/hive_boxes.dart';
import 'package:getman/core/storage/hive_helpers.dart';
import 'package:getman/features/tabs/data/models/request_tab_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class TabsLocalDataSource {
  Future<List<HttpRequestTabModel>> getTabs();
  Future<void> saveTabs(List<HttpRequestTabModel> tabs);
}

class TabsLocalDataSourceImpl implements TabsLocalDataSource {
  Box<HttpRequestTabModel> _box() => Hive.box<HttpRequestTabModel>(HiveBoxes.tabs);

  @override
  Future<List<HttpRequestTabModel>> getTabs() async {
    try {
      return _box().values.toList();
    } catch (e) {
      throw PersistenceException('Failed to read tabs', cause: e);
    }
  }

  @override
  Future<void> saveTabs(List<HttpRequestTabModel> tabs) async {
    try {
      await replaceAllInBox(_box(), tabs);
    } catch (e) {
      throw PersistenceException('Failed to save tabs', cause: e);
    }
  }
}
