import 'package:flutter_test/flutter_test.dart';
import 'package:getman/features/settings/data/models/settings_model.dart';
import 'package:getman/features/settings/domain/entities/settings_entity.dart';

void main() {
  group('SettingsModel themeId', () {
    test('fromEntity default themeId is brutalist', () {
      final model = SettingsModel.fromEntity(const SettingsEntity());
      expect(model.themeId, 'brutalist');
    });

    test('json roundtrip preserves themeId', () {
      final model = SettingsModel(themeId: 'editorial');
      final roundTripped = SettingsModel.fromJson(model.toJson());
      expect(roundTripped.themeId, 'editorial');
    });

    test('entity roundtrip preserves themeId', () {
      const entity = SettingsEntity(themeId: 'editorial');
      final model = SettingsModel.fromEntity(entity);
      expect(model.toEntity().themeId, 'editorial');
    });

    test('copyWith overrides themeId but keeps other fields', () {
      final original = SettingsModel(themeId: 'brutalist', historyLimit: 50);
      final copy = original.copyWith(themeId: 'editorial');
      expect(copy.themeId, 'editorial');
      expect(copy.historyLimit, 50);
    });
  });

  group('SettingsModel activeEnvironmentId', () {
    test('default is null', () {
      expect(const SettingsEntity().activeEnvironmentId, isNull);
      expect(SettingsModel().activeEnvironmentId, isNull);
    });

    test('entity roundtrip preserves a set id', () {
      const entity = SettingsEntity(activeEnvironmentId: 'env-42');
      final back = SettingsModel.fromEntity(entity).toEntity();
      expect(back.activeEnvironmentId, 'env-42');
    });

    test('entity roundtrip preserves null', () {
      const entity = SettingsEntity(activeEnvironmentId: null);
      final back = SettingsModel.fromEntity(entity).toEntity();
      expect(back.activeEnvironmentId, isNull);
    });

    test('json roundtrip preserves id', () {
      final model = SettingsModel(activeEnvironmentId: 'x');
      expect(SettingsModel.fromJson(model.toJson()).activeEnvironmentId, 'x');
    });

    test('SettingsEntity.copyWith can clear to null explicitly', () {
      const entity = SettingsEntity(activeEnvironmentId: 'x');
      final cleared = entity.copyWith(activeEnvironmentId: null);
      expect(cleared.activeEnvironmentId, isNull);
    });

    test('SettingsEntity.copyWith without arg preserves previous id', () {
      const entity = SettingsEntity(activeEnvironmentId: 'x');
      final preserved = entity.copyWith(themeId: 'other');
      expect(preserved.activeEnvironmentId, 'x');
    });
  });

  group('SettingsModel network + workspace fields', () {
    test('defaults match the network baseline', () {
      const e = SettingsEntity();
      expect(e.connectTimeoutMs, 30000);
      expect(e.sendTimeoutMs, 30000);
      expect(e.receiveTimeoutMs, 60000);
      expect(e.followRedirects, isTrue);
      expect(e.verifySsl, isTrue);
      expect(e.proxyUrl, isNull);
      expect(e.workspacePath, isNull);
    });

    test('json roundtrip preserves the new fields', () {
      final model = SettingsModel(
        connectTimeoutMs: 1000,
        sendTimeoutMs: 2000,
        receiveTimeoutMs: 3000,
        followRedirects: false,
        verifySsl: false,
        proxyUrl: 'localhost:8888',
        workspacePath: '/tmp/ws',
      );
      final back = SettingsModel.fromJson(model.toJson());
      expect(back.connectTimeoutMs, 1000);
      expect(back.sendTimeoutMs, 2000);
      expect(back.receiveTimeoutMs, 3000);
      expect(back.followRedirects, isFalse);
      expect(back.verifySsl, isFalse);
      expect(back.proxyUrl, 'localhost:8888');
      expect(back.workspacePath, '/tmp/ws');
    });

    test('entity roundtrip preserves the new fields', () {
      const entity = SettingsEntity(
        connectTimeoutMs: 5,
        verifySsl: false,
        proxyUrl: 'p:1',
        workspacePath: '/ws',
      );
      final back = SettingsModel.fromEntity(entity).toEntity();
      expect(back.connectTimeoutMs, 5);
      expect(back.verifySsl, isFalse);
      expect(back.proxyUrl, 'p:1');
      expect(back.workspacePath, '/ws');
    });

    test('copyWith clears proxyUrl / workspacePath via the sentinel', () {
      const entity = SettingsEntity(proxyUrl: 'p:1', workspacePath: '/ws');
      expect(entity.copyWith(proxyUrl: null).proxyUrl, isNull);
      expect(entity.copyWith(workspacePath: null).workspacePath, isNull);
      // Omitting keeps them.
      final kept = entity.copyWith(verifySsl: false);
      expect(kept.proxyUrl, 'p:1');
      expect(kept.workspacePath, '/ws');
    });
  });
}
