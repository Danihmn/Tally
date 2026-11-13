import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/core/utils/date_formatter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('DateFormatter', () {
    test('formats_day_month_year_with_zero_padding', () {
      expect(DateFormatter.date(DateTime(2026, 1, 5)), '05/01/2026');
      expect(DateFormatter.dayMonth(DateTime(2026, 11, 12)), '12/11');
    });

    test('formats_month_name_in_portuguese', () {
      expect(
        DateFormatter.monthYear(DateTime(2026, 11, 1)),
        'novembro de 2026',
      );
    });

    test('parses_a_valid_date_and_rejects_impossible_or_malformed_ones', () {
      expect(DateFormatter.parse('12/11/2026'), DateTime(2026, 11, 12));
      expect(DateFormatter.parse('31/02/2026'), isNull);
      expect(DateFormatter.parse('2026-11-12'), isNull);
      expect(DateFormatter.parse('1/1/2026'), isNull);
    });

    test('formats_the_api_date_as_year_month_day', () {
      expect(DateFormatter.toApiDate(DateTime(2026, 3, 9)), '2026-03-09');
    });
  });
}
