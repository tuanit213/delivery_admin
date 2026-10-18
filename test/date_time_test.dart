import 'package:flutter_test/flutter_test.dart';
import 'package:admin/core/utils/date_time_utils.dart';

void main() {
  test('UTC order dates display Vietnam time and handle midnight', () {
    expect(vietnamTime('2026-10-15T15:00:00Z')?.hour, 22);
    expect(vietnamTime('2026-10-15T15:00:00')?.hour, 22);
    expect(vietnamTime('2026-10-15T21:00:00Z')?.day, 16);
    expect(vietnamTime('2026-10-15T21:00:00Z')?.hour, 4);
    expect(vietnamTime('invalid'), isNull);
  });
}
