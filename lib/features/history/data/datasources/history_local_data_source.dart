import 'package:getman/core/error/exceptions.dart';
import 'package:getman/core/storage/hive_boxes.dart';
import 'package:getman/features/history/data/models/request_config_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class HistoryLocalDataSource {
  Future<List<HttpRequestConfig>> getHistory();
  Future<void> addToHistory(HttpRequestConfig config, int limit);
  Stream<void> watch();
}

class HistoryLocalDataSourceImpl implements HistoryLocalDataSource {
  Box<HttpRequestConfig> _box() => Hive.box<HttpRequestConfig>(HiveBoxes.history);

  @override
  Future<List<HttpRequestConfig>> getHistory() async {
    try {
      return _box().values.toList();
    } catch (e) {
      throw PersistenceException('Failed to read history', cause: e);
    }
  }

  @override
  Future<void> addToHistory(HttpRequestConfig config, int limit) async {
    try {
      final box = _box();
      // HttpRequestConfig.== treats same-signature requests as equal (see
      // request_config_model.dart), which is the contract this dedup relies on.
      final existingIndex = box.values.toList().indexOf(config);
      if (existingIndex != -1) {
        await box.deleteAt(existingIndex);
      }

      await box.add(config);

      while (box.length > limit && box.isNotEmpty) {
        await box.deleteAt(0);
      }
    } catch (e) {
      throw PersistenceException('Failed to add to history', cause: e);
    }
  }

  @override
  Stream<void> watch() => _box().watch().map((_) {});
}
