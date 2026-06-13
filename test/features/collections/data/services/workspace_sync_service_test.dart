import 'package:flutter_test/flutter_test.dart';
import 'package:getman/features/collections/data/datasources/workspace_collections_data_source.dart';
import 'package:getman/features/collections/data/services/workspace_sync_service.dart';
import 'package:getman/features/collections/domain/entities/collection_node_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements WorkspaceCollectionsDataSource {}

void main() {
  setUpAll(() => registerFallbackValue(<CollectionNodeEntity>[]));

  late _MockDataSource ds;

  setUp(() {
    ds = _MockDataSource();
    when(() => ds.write(any(), any())).thenAnswer((_) async {});
    when(() => ds.read(any())).thenAnswer((_) async => const []);
  });

  test('scheduleMirror debounces bursts into a single write', () async {
    final service = WorkspaceSyncService(ds, debounce: const Duration(milliseconds: 5));
    addTearDown(service.dispose);

    service.scheduleMirror('/ws', const []);
    service.scheduleMirror('/ws', const []); // cancels the first
    await Future<void>.delayed(const Duration(milliseconds: 30));

    verify(() => ds.write('/ws', any())).called(1);
  });

  test('read delegates to the data source', () async {
    final service = WorkspaceSyncService(ds);
    addTearDown(service.dispose);

    await service.read('/ws');
    verify(() => ds.read('/ws')).called(1);
  });

  test('a write failure is swallowed (never breaks the session)', () async {
    when(() => ds.write(any(), any())).thenThrow(Exception('disk full'));
    final service = WorkspaceSyncService(ds, debounce: const Duration(milliseconds: 5));
    addTearDown(service.dispose);

    service.scheduleMirror('/ws', const []);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    // No throw escapes; reaching here is the assertion.
  });
}
