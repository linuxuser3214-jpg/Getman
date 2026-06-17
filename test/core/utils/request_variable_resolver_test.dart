import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/utils/request_variable_resolver.dart';
import 'package:getman/features/collections/domain/entities/collection_node_entity.dart';
import 'package:getman/features/environments/domain/entities/environment_entity.dart';

void main() {
  CollectionNodeEntity leaf(String id) =>
      CollectionNodeEntity(id: id, name: 'r', isFolder: false);

  final tree = [
    CollectionNodeEntity(
      id: 'f1',
      name: 'API',
      variables: const {'base': 'collection', 'only_c': 'c'},
      children: [leaf('L')],
    ),
  ];

  final envs = [
    EnvironmentEntity(
      id: 'e1',
      name: 'Prod',
      variables: const {'base': 'env', 'only_e': 'e'},
    ),
  ];

  test('environment overlays collection (env wins on clash)', () {
    final r = RequestVariableResolver.variablesFor(
      environments: envs,
      activeEnvironmentId: 'e1',
      collections: tree,
      collectionNodeId: 'L',
    );
    expect(r['base'], 'env'); // env wins
    expect(r['only_c'], 'c'); // collection-only survives
    expect(r['only_e'], 'e'); // env-only survives
  });

  test('no active environment -> collection layer only', () {
    final r = RequestVariableResolver.variablesFor(
      environments: envs,
      activeEnvironmentId: null,
      collections: tree,
      collectionNodeId: 'L',
    );
    expect(r, {'base': 'collection', 'only_c': 'c'});
  });

  test('unlinked tab (null node id) -> environment only', () {
    final r = RequestVariableResolver.variablesFor(
      environments: envs,
      activeEnvironmentId: 'e1',
      collections: tree,
      collectionNodeId: null,
    );
    expect(r, {'base': 'env', 'only_e': 'e'});
  });

  test('neither layer -> empty', () {
    final r = RequestVariableResolver.variablesFor(
      environments: const [],
      activeEnvironmentId: null,
      collections: const [],
      collectionNodeId: null,
    );
    expect(r, isEmpty);
  });
}
