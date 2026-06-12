import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/request_config_entity.dart';
import 'package:getman/core/error/failures.dart';
import 'package:getman/core/network/http_response.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';
import 'package:getman/features/tabs/domain/repositories/tabs_repository.dart';
import 'package:getman/features/tabs/domain/usecases/send_request_use_case.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_bloc.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_event.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_state.dart';
import 'package:mocktail/mocktail.dart';

class MockTabsRepository extends Mock implements TabsRepository {}

class MockSendRequestUseCase extends Mock implements SendRequestUseCase {}

class _FakeConfig extends Fake implements HttpRequestConfigEntity {}

void main() {
  late MockTabsRepository repository;
  late MockSendRequestUseCase sendRequestUseCase;
  late TabsBloc bloc;

  setUpAll(() {
    registerFallbackValue(_FakeConfig());
  });

  setUp(() {
    repository = MockTabsRepository();
    sendRequestUseCase = MockSendRequestUseCase();
    when(() => repository.saveTabs(any())).thenAnswer((_) async {});
    bloc = TabsBloc(repository: repository, sendRequestUseCase: sendRequestUseCase);
  });

  tearDown(() => bloc.close());

  HttpRequestTabEntity tab(String id, {bool isSending = false}) => HttpRequestTabEntity(
        tabId: id,
        isSending: isSending,
        config: HttpRequestConfigEntity(id: id, url: 'https://$id.dev'),
      );

  Future<void> loadWith(List<HttpRequestTabEntity> tabs) async {
    when(() => repository.getTabs()).thenAnswer((_) async => tabs);
    bloc.add(const LoadTabs());
    await expectLater(bloc.stream, emitsThrough(predicate<TabsState>((s) => s.isLoading == false)));
  }

  void stubSend(Future<HttpResponseEntity> Function() answer) {
    when(() => sendRequestUseCase.call(
          config: any(named: 'config'),
          envVars: any(named: 'envVars'),
          cancelHandle: any(named: 'cancelHandle'),
        )).thenAnswer((_) => answer());
  }

  group('LoadTabs', () {
    test('creates a single empty tab when nothing is persisted', () async {
      await loadWith([]);
      expect(bloc.state.tabs, hasLength(1));
      expect(bloc.state.activeIndex, 0);
      expect(bloc.state.tabs.single.config.url, isEmpty);
    });

    test('resets stale isSending flags from a previous session', () async {
      await loadWith([tab('a', isSending: true), tab('b')]);
      expect(bloc.state.tabs.map((t) => t.isSending), everyElement(isFalse));
    });
  });

  group('tab management', () {
    test('RemoveTab drops the tab by id and clamps the active index', () async {
      await loadWith([tab('a'), tab('b'), tab('c')]);
      bloc.add(const SetActiveIndex(2));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const RemoveTab('c'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.tabs.map((t) => t.tabId), ['a', 'b']);
      expect(bloc.state.activeIndex, 1);
    });

    test('RemoveTab for an unknown id is a no-op', () async {
      await loadWith([tab('a')]);
      bloc.add(const RemoveTab('ghost'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.tabs, hasLength(1));
    });

    test('CloseOtherTabs keeps only the addressed tab', () async {
      await loadWith([tab('a'), tab('b'), tab('c')]);
      bloc.add(const CloseOtherTabs('b'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.tabs.map((t) => t.tabId), ['b']);
      expect(bloc.state.activeIndex, 0);
    });

    test('CloseTabsToTheRight keeps the addressed tab and everything left of it', () async {
      await loadWith([tab('a'), tab('b'), tab('c')]);
      bloc.add(const SetActiveIndex(2));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CloseTabsToTheRight('a'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.tabs.map((t) => t.tabId), ['a']);
      expect(bloc.state.activeIndex, 0);
    });

    test('DuplicateTab inserts an unsaved copy right after the source', () async {
      await loadWith([tab('a'), tab('b')]);
      bloc.add(const DuplicateTab('a'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.tabs, hasLength(3));
      final copy = bloc.state.tabs[1];
      expect(copy.tabId, isNot('a'));
      expect(copy.config.url, 'https://a.dev');
      expect(copy.collectionNodeId, isNull);
      expect(bloc.state.activeIndex, 1);
    });

    test('AddTab focuses an existing tab for the same collection node instead of duplicating',
        () async {
      await loadWith([]);
      bloc.add(const AddTab(
        config: HttpRequestConfigEntity(id: 'n1'),
        collectionNodeId: 'node-1',
        collectionName: 'Login',
      ));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.tabs, hasLength(2));

      bloc.add(const SetActiveIndex(0));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AddTab(
        config: HttpRequestConfigEntity(id: 'n1'),
        collectionNodeId: 'node-1',
        collectionName: 'Login',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.tabs, hasLength(2), reason: 'no duplicate tab for the same node');
      expect(bloc.state.activeIndex, 1);
    });
  });

  group('SetActiveIndex', () {
    test('ignores out-of-range indices so widgets can index tabs safely', () async {
      await loadWith([]);
      expect(bloc.state.activeIndex, 0);

      bloc.add(const SetActiveIndex(99));
      bloc.add(const SetActiveIndex(-1));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.activeIndex, 0);
    });
  });

  group('SendRequest', () {
    const response = HttpResponseEntity(
      statusCode: 200,
      body: '{"ok":true}',
      headers: {'content-type': 'application/json'},
      durationMs: 42,
    );

    test('applies the response to the addressed tab', () async {
      await loadWith([tab('a')]);
      stubSend(() async => response);

      bloc.add(const SendRequest(tabId: 'a'));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<TabsState>(
          (s) => s.tabs.single.isSending == false && s.tabs.single.response == response,
        )),
      );
    });

    test('targets the tab by id even when another tab is active', () async {
      await loadWith([tab('a'), tab('b')]);
      bloc.add(const SetActiveIndex(1));
      stubSend(() async => response);

      bloc.add(const SendRequest(tabId: 'a'));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<TabsState>((s) =>
            s.tabs.byId('a')?.response == response && s.tabs.byId('b')?.response == null)),
      );
    });

    test('a cancelled request clears isSending without recording a response', () async {
      await loadWith([tab('a')]);
      stubSend(() async =>
          throw const NetworkFailure('cancelled', type: NetworkFailureType.cancelled));

      bloc.add(const SendRequest(tabId: 'a'));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<TabsState>(
          (s) => s.tabs.single.isSending == false && s.tabs.single.response == null,
        )),
      );
    });

    test('a network failure materializes as an error response on the tab', () async {
      await loadWith([tab('a')]);
      stubSend(() async =>
          throw const NetworkFailure('connection refused', type: NetworkFailureType.connection));

      bloc.add(const SendRequest(tabId: 'a'));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<TabsState>((s) {
          final r = s.tabs.single.response;
          return s.tabs.single.isSending == false &&
              r != null &&
              r.statusCode == 0 &&
              r.body == 'connection refused';
        })),
      );
    });

    test('resets isSending when the use case throws a non-NetworkFailure error', () async {
      await loadWith([]);
      final tabId = bloc.state.tabs.single.tabId;
      when(() => sendRequestUseCase.call(
            config: any(named: 'config'),
            envVars: any(named: 'envVars'),
            cancelHandle: any(named: 'cancelHandle'),
          )).thenThrow(StateError('boom'));

      bloc.add(SendRequest(tabId: tabId));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<TabsState>(
          (s) => s.tabs.single.tabId == tabId && s.tabs.single.isSending == false,
        )),
      );
    });
  });
}
