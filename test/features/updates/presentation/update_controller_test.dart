import 'package:flutter_test/flutter_test.dart';
import 'package:getman/features/updates/domain/entities/release_info.dart';
import 'package:getman/features/updates/domain/repositories/update_repository.dart';
import 'package:getman/features/updates/presentation/update_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements UpdateRepository {}

void main() {
  setUpAll(() => registerFallbackValue(UpdatePlatform.macos));

  late _MockRepo repo;
  late UpdateController controller;

  setUp(() {
    repo = _MockRepo();
    controller = UpdateController(repo);
  });

  test('fetchLatestRelease delegates to repo and caches the result', () async {
    const info = ReleaseInfo(version: '1.1.0', changelog: 'c', assetUrl: 'u');
    when(() => repo.fetchLatestRelease(any())).thenAnswer((_) async => info);

    final result = await controller.fetchLatestRelease(UpdatePlatform.macos);
    expect(result, info);
    expect(controller.cachedRelease, info);
  });

  test('checkNow sets manualInFlight and invokes triggerCheck', () {
    var called = false;
    controller.triggerCheck = () => called = true;
    // ignore: cascade_invocations — sequential mutations are setup-only
    controller.checkNow();
    expect(controller.manualInFlight, isTrue);
    expect(called, isTrue);
  });
}
