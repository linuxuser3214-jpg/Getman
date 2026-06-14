import 'package:getman/core/domain/entities/request_config_entity.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';

class TabDirtyChecker {
  const TabDirtyChecker();

  /// Whether [tab] has unsaved changes. For a tab linked to a collection node,
  /// compares against the saved config looked up in [savedConfigs] (the
  /// O(1) id→config index from CollectionsState); for an unlinked tab,
  /// compares against a pristine default config.
  bool call({
    required HttpRequestTabEntity tab,
    required Map<String, HttpRequestConfigEntity> savedConfigs,
  }) {
    final nodeId = tab.collectionNodeId;
    if (nodeId == null) {
      return tab.config != HttpRequestConfigEntity(id: tab.config.id);
    }
    final saved = savedConfigs[nodeId];
    if (saved == null) return true;
    return tab.config != saved;
  }
}
