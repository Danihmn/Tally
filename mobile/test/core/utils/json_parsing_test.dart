import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/json_parsing.dart';

void main() {
  group('parseDecimal', () {
    test('reads_strings_and_numbers_exactly', () {
      expect(parseDecimal('412.37'), Decimal.parse('412.37'));
      expect(parseDecimal(412.37), Decimal.parse('412.37'));
      expect(parseDecimal(8900), Decimal.parse('8900'));
    });

    test('throws_a_format_exception_for_other_types', () {
      expect(() => parseDecimal(null), throwsFormatException);
      expect(() => parseDecimal(true), throwsFormatException);
      expect(() => parseDecimal('abc'), throwsFormatException);
    });

    test('null_variant_returns_null', () {
      expect(parseDecimalOrNull(null), isNull);
      expect(parseDecimalOrNull('1.5'), Decimal.parse('1.5'));
    });
  });

  group('parseDateTime', () {
    test('reads_iso_strings_and_keeps_utc', () {
      expect(
        parseDateTime('2026-11-12T10:30:00Z'),
        DateTime.utc(2026, 11, 12, 10, 30),
      );
      expect(parseDateTimeOrNull(null), isNull);
      expect(() => parseDateTime(5), throwsFormatException);
    });
  });

  group('requireString', () {
    test('returns_a_non_empty_text', () {
      expect(requireString('abc', 'name'), 'abc');
    });

    test('throws_a_format_exception_for_empty_or_other_types', () {
      expect(() => requireString('', 'name'), throwsFormatException);
      expect(() => requireString(null, 'name'), throwsFormatException);
      expect(() => requireString(5, 'name'), throwsFormatException);
    });
  });

  group('parseApiDate', () {
    test('reads_a_date_as_local_midnight_of_the_same_day', () {
      final date = parseApiDate('2026-11-12');

      expect((date.year, date.month, date.day), (2026, 11, 12));
      expect(date.isUtc, isFalse);
      expect((date.hour, date.minute), (0, 0));
    });

    test('rejects_impossible_dates_and_other_formats', () {
      expect(() => parseApiDate('2026-02-30'), throwsFormatException);
      expect(() => parseApiDate('2026-13-01'), throwsFormatException);
      expect(() => parseApiDate('12/11/2026'), throwsFormatException);
      expect(() => parseApiDate('2026-11-12T10:00:00Z'), throwsFormatException);
      expect(() => parseApiDate(null), throwsFormatException);
    });
  });

  group('requireInt', () {
    test('reads_a_whole_number', () {
      expect(requireInt(7, 'count'), 7);
    });

    test('rejects_text_decimals_and_null', () {
      expect(() => requireInt('7', 'count'), throwsFormatException);
      expect(() => requireInt(7.5, 'count'), throwsFormatException);
      expect(() => requireInt(null, 'count'), throwsFormatException);
    });
  });
}
