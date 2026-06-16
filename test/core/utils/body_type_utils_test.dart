import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/body_type.dart';
import 'package:getman/core/utils/body_type_utils.dart';

void main() {
  group('BodyTypeUtils.applyContentType', () {
    test('urlencoded forces the form content-type', () {
      final h = <String, String>{};
      BodyTypeUtils.applyContentType(h, BodyType.urlencoded);
      expect(h['Content-Type'], 'application/x-www-form-urlencoded');
    });
    test('multipart strips content-type (Dio adds the boundary)', () {
      final h = <String, String>{'content-type': 'text/plain'};
      BodyTypeUtils.applyContentType(h, BodyType.multipart);
      expect(h.keys.any((k) => k.toLowerCase() == 'content-type'), isFalse);
    });
    test('binary sets octet-stream only when no custom type is present', () {
      final h = <String, String>{};
      BodyTypeUtils.applyContentType(h, BodyType.binary);
      expect(h['Content-Type'], 'application/octet-stream');
    });
    test('binary respects an existing custom content-type', () {
      final h = <String, String>{'Content-Type': 'image/png'};
      BodyTypeUtils.applyContentType(h, BodyType.binary);
      expect(h['Content-Type'], 'image/png');
    });
    test('none and raw leave headers untouched', () {
      final none = <String, String>{};
      final raw = <String, String>{'Content-Type': 'application/json'};
      BodyTypeUtils.applyContentType(none, BodyType.none);
      BodyTypeUtils.applyContentType(raw, BodyType.raw);
      expect(none, isEmpty);
      expect(raw['Content-Type'], 'application/json');
    });
  });
}
