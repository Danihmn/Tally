import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/month_period.dart';

void main() {
  final today = DateTime(2026, 11, 13);
  final november = MonthPeriod.containing(DateTime(2026, 11, 20, 15, 30));

  group('MonthPeriod', () {
    test('contains_any_day_of_the_month_and_starts_on_day_one', () {
      expect(november.firstDay, DateTime(2026, 11));
    });

    test('knows_the_last_day_and_the_size_of_the_month', () {
      expect(november.lastDay, DateTime(2026, 11, 30));
      expect(november.daysInMonth, 30);
      expect(MonthPeriod.containing(DateTime(2028, 2, 10)).daysInMonth, 29);
      expect(MonthPeriod.containing(DateTime(2026, 12, 1)).daysInMonth, 31);
    });

    test('goes_to_the_previous_and_next_month_across_the_year', () {
      expect(
        MonthPeriod.containing(DateTime(2027, 1, 5)).previous.firstDay,
        DateTime(2026, 12),
      );
      expect(
        MonthPeriod.containing(DateTime(2026, 12, 5)).next.firstDay,
        DateTime(2027, 1),
      );
    });

    test('the_whole_month_goes_from_day_one_to_the_last_day', () {
      expect(
        november.wholeMonth,
        DateRange(from: DateTime(2026, 11), to: DateTime(2026, 11, 30)),
      );
    });

    test('is_current_only_for_the_month_of_today', () {
      expect(november.isCurrent(today), isTrue);
      expect(november.previous.isCurrent(today), isFalse);
      expect(november.next.isCurrent(today), isFalse);
    });
  });

  group('MonthPeriod.spendingRange', () {
    test('the_current_month_goes_until_yesterday', () {
      expect(
        november.spendingRange(today),
        DateRange(from: DateTime(2026, 11), to: DateTime(2026, 11, 12)),
      );
    });

    test('on_day_two_it_is_only_day_one', () {
      expect(
        november.spendingRange(DateTime(2026, 11, 2)),
        DateRange(from: DateTime(2026, 11), to: DateTime(2026, 11)),
      );
    });

    test('on_day_one_no_day_is_over_yet', () {
      expect(november.spendingRange(DateTime(2026, 11, 1)), isNull);
    });

    test('a_past_month_is_whole', () {
      expect(
        november.previous.spendingRange(today),
        DateRange(from: DateTime(2026, 10), to: DateTime(2026, 10, 31)),
      );
    });
  });

  group('MonthPeriod navigation limits', () {
    test('cannot_go_forward_from_the_current_month', () {
      expect(november.canGoNext(today), isFalse);
      expect(november.previous.canGoNext(today), isTrue);
    });

    test('can_go_back_eleven_months_and_no_more', () {
      var month = november;
      for (var i = 0; i < MonthPeriod.maxMonthsBack; i++) {
        expect(month.canGoPrevious(today), isTrue, reason: 'step $i');
        month = month.previous;
      }
      expect(month.firstDay, DateTime(2025, 12));
      expect(month.canGoPrevious(today), isFalse);
    });

    test('counts_months_across_years', () {
      expect(
        MonthPeriod.containing(DateTime(2025, 12)).monthsBefore(today),
        11,
      );
      expect(november.monthsBefore(today), 0);
    });
  });
}
