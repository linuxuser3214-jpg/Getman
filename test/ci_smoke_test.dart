import 'package:flutter_test/flutter_test.dart';

// TEMPORARY: a deliberate failure to confirm CI catches problems and reports
// them on the PR. Revert (delete this file) before merging.
void main() {
  test('intentional CI failure — delete this file before merge', () {
    expect(1, equals(2), reason: 'deliberate failure to verify CI goes red');
  });
}
