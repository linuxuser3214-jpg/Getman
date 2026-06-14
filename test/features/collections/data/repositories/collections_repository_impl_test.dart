import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/error/exceptions.dart';
import 'package:getman/core/error/failures.dart';
import 'package:getman/features/collections/data/datasources/collections_local_data_source.dart';
import 'package:getman/features/collections/data/models/collection_node_model.dart';
import 'package:getman/features/collections/data/repositories/collections_repository_impl.dart';
import 'package:getman/features/collections/domain/entities/collection_node_entity.dart';

class _FakeCollectionsDataSource implements CollectionsLocalDataSource {
  List<CollectionNode> stored;
  List<CollectionNode>? savedList;
  bool throwOnGet = false;
  _FakeCollectionsDataSource([this.stored = const []]);

  @override
  Future<List<CollectionNode>> getCollections() async {
    if (throwOnGet) throw PersistenceException('boom');
    return stored;
  }

  @override
  Future<void> saveCollections(List<CollectionNode> collections) async =>
      savedList = collections;
}

void main() {
  test('getCollections maps each model (with children) to an entity', () async {
    final ds = _FakeCollectionsDataSource([
      CollectionNode.fromEntity(const CollectionNodeEntity(
        id: 'root',
        name: 'Root',
        children: [CollectionNodeEntity(id: 'child', name: 'Child', isFolder: false)],
      )),
    ]);
    final repo = CollectionsRepositoryImpl(ds);

    final result = await repo.getCollections();
    expect(result, hasLength(1));
    expect(result.single.name, 'Root');
    expect(result.single.children.single.name, 'Child');
  });

  test('saveCollections converts the forest to models', () async {
    final ds = _FakeCollectionsDataSource();
    final repo = CollectionsRepositoryImpl(ds);

    await repo.saveCollections(const [
      CollectionNodeEntity(id: 'a', name: 'A'),
      CollectionNodeEntity(id: 'b', name: 'B'),
    ]);

    expect(ds.savedList?.map((m) => m.id), ['a', 'b']);
  });

  test('translates a PersistenceException into a PersistenceFailure', () async {
    final ds = _FakeCollectionsDataSource()..throwOnGet = true;
    final repo = CollectionsRepositoryImpl(ds);

    expect(repo.getCollections(), throwsA(isA<PersistenceFailure>()));
  });
}
