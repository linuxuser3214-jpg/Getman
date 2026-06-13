import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:getman/features/collections/data/datasources/workspace_collections_data_source.dart';
import 'package:getman/features/collections/domain/entities/collection_node_entity.dart';

/// Coordinates the one-directional, in-session mirror of collections to disk.
///
/// Strategy (pragmatic v1): Hive is the source of truth during a session.
/// On workspace open the caller imports disk → Hive ([read]); thereafter every
/// mutation mirrors Hive → disk ([scheduleMirror], debounced, best-effort).
/// No file watcher — manual git edits are picked up on an explicit reload.
class WorkspaceSyncService {
  final WorkspaceCollectionsDataSource dataSource;
  final Duration debounce;
  Timer? _timer;

  WorkspaceSyncService(this.dataSource, {this.debounce = const Duration(seconds: 1)});

  Future<List<CollectionNodeEntity>> read(String root) => dataSource.read(root);

  /// Debounced Hive → disk mirror. Coalesces bursts of mutations into one write.
  void scheduleMirror(String root, List<CollectionNodeEntity> forest) {
    _timer?.cancel();
    _timer = Timer(debounce, () => _mirror(root, forest));
  }

  Future<void> _mirror(String root, List<CollectionNodeEntity> forest) async {
    try {
      await dataSource.write(root, forest);
    } catch (e) {
      // Best-effort: a failed mirror must never break the in-app session.
      debugPrint('Workspace mirror failed: $e');
    }
  }

  void dispose() => _timer?.cancel();
}
