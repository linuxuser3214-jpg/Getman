import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/utils/bulk_kv_codec.dart';

void main() {
  group('BulkKvCodec.serialize', () {
    test('empty list serializes to empty string', () {
      expect(BulkKvCodec.serialize(const []), '');
    });

    test('rows become one "key: value" line each, canonical order', () {
      final text = BulkKvCodec.serialize(const [
        ('Accept', '*/*'),
        ('Authorization', 'Bearer abc'),
      ]);
      expect(text, 'Accept: */*\nAuthorization: Bearer abc');
    });

    test('value is emitted verbatim (no trimming on serialize)', () {
      expect(
        BulkKvCodec.serialize(const [('X', '  spaced  ')]),
        'X:   spaced  ',
      );
    });

    test('empty-key rows are skipped', () {
      expect(BulkKvCodec.serialize(const [('', 'orphan'), ('K', 'v')]), 'K: v');
    });

    test('a key with an empty value still emits "key: "', () {
      expect(BulkKvCodec.serialize(const [('Accept', '')]), 'Accept: ');
    });
  });

  group('BulkKvCodec.parse', () {
    test('empty / whitespace-only input yields no rows', () {
      expect(BulkKvCodec.parse(''), const <(String, String)>[]);
      expect(BulkKvCodec.parse('   \n\t\n  '), const <(String, String)>[]);
    });

    test('splits on the first colon and trims both sides (D2)', () {
      expect(BulkKvCodec.parse('Accept :  */*  '), const [('Accept', '*/*')]);
    });

    test(
      'value containing a colon keeps everything after the first one (D2)',
      () {
        expect(
          BulkKvCodec.parse('Authorization: Bearer a:b'),
          const [('Authorization', 'Bearer a:b')],
        );
      },
    );

    test('a line with no colon becomes (key, "") (D3)', () {
      expect(BulkKvCodec.parse('Accept'), const [('Accept', '')]);
    });

    test('blank lines between pairs are dropped (D4)', () {
      expect(
        BulkKvCodec.parse('A: 1\n\n   \nB: 2'),
        const [('A', '1'), ('B', '2')],
      );
    });

    test('a line whose key trims to empty is dropped (D5)', () {
      expect(BulkKvCodec.parse(': value'), const <(String, String)>[]);
      expect(BulkKvCodec.parse('   : x'), const <(String, String)>[]);
    });

    test('trailing newline produces no phantom pair (D4)', () {
      expect(BulkKvCodec.parse('A: 1\n'), const [('A', '1')]);
    });

    test('duplicate keys are preserved in order', () {
      expect(
        BulkKvCodec.parse('tag: a\ntag: b'),
        const [('tag', 'a'), ('tag', 'b')],
      );
    });
  });

  group('round-trip parse(serialize(rows)) == rows', () {
    test('representative canonical rows survive a round-trip', () {
      const rows = [
        ('Accept', '*/*'),
        ('Authorization', 'Bearer a:b'),
        ('Empty', ''),
        ('tag', 'a'),
        ('tag', 'b'),
      ];
      expect(BulkKvCodec.parse(BulkKvCodec.serialize(rows)), rows);
    });
  });
}
