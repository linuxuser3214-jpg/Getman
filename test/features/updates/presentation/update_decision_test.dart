import 'package:flutter_test/flutter_test.dart';
import 'package:getman/features/updates/presentation/update_decision.dart';

void main() {
  group('isNewerVersion', () {
    test('detects a newer patch/minor/major', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });
    test('equal or older is not newer', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });
    test('malformed versions are not newer', () {
      expect(isNewerVersion('abc', '1.0.0'), isFalse);
    });
  });

  group('shouldPromptForUpdate', () {
    bool call({
      bool autoCheck = true,
      String? latest = '1.1.0',
      String current = '1.0.0',
      String? skipped,
      bool manual = false,
    }) => shouldPromptForUpdate(
      autoCheck: autoCheck,
      latest: latest,
      current: current,
      skipped: skipped,
      manual: manual,
    );

    test('prompts on a newer version during auto-check', () {
      expect(call(), isTrue);
    });
    test('no prompt when latest is null', () {
      expect(call(latest: null), isFalse);
    });
    test('no prompt when not newer', () {
      expect(call(latest: '1.0.0'), isFalse);
    });
    test(
      'manual check always prompts when newer (ignores skip + autoCheck)',
      () {
        expect(call(manual: true, autoCheck: false, skipped: '1.1.0'), isTrue);
      },
    );
    test('auto-check off suppresses the prompt', () {
      expect(call(autoCheck: false), isFalse);
    });
    test('skipped version is not auto-prompted', () {
      expect(call(skipped: '1.1.0'), isFalse);
    });
    test('a different skipped version still prompts', () {
      expect(call(skipped: '1.0.5'), isTrue);
    });
  });
}
