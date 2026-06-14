import 'package:flutter_test/flutter_test.dart';
import 'package:getman/features/collections/data/models/collection_node_model.dart';
import 'package:getman/features/collections/domain/entities/collection_node_entity.dart';

void main() {
  group('CollectionNode <-> entity', () {
    test('round-trips the description (incl. nested children)', () {
      const entity = CollectionNodeEntity(
        id: 'root',
        name: 'Root',
        description: 'top-level notes',
        children: [
          CollectionNodeEntity(id: 'child', name: 'Child', isFolder: false, description: 'child notes'),
        ],
      );

      final back = CollectionNode.fromEntity(entity).toEntity();

      expect(back.description, 'top-level notes');
      expect(back.children.single.description, 'child notes');
    });

    test('a null description round-trips as null', () {
      const entity = CollectionNodeEntity(id: 'a', name: 'A');
      final back = CollectionNode.fromEntity(entity).toEntity();
      expect(back.description, isNull);
    });
  });

  group('CollectionNodeEntity.copyWith', () {
    test('preserves description when not provided', () {
      const node = CollectionNodeEntity(id: 'a', name: 'A', description: 'keep');
      expect(node.copyWith(name: 'B').description, 'keep');
    });

    test('updates description when provided (incl. empty to clear)', () {
      const node = CollectionNodeEntity(id: 'a', name: 'A', description: 'old');
      expect(node.copyWith(description: 'new').description, 'new');
      expect(node.copyWith(description: '').description, '');
    });

    test('equality reflects the description', () {
      const a = CollectionNodeEntity(id: 'a', name: 'A', description: 'x');
      const b = CollectionNodeEntity(id: 'a', name: 'A', description: 'y');
      expect(a == b, isFalse);
    });
  });
}
