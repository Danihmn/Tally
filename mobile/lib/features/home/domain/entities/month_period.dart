import 'package:equatable/equatable.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';

/// The month shown on the home, and the days of it that have numbers.
///
/// The API works with whole days that are over: the current month goes from
/// day 1 until yesterday. A past month is whole. All dates are date-only.
class MonthPeriod extends Equatable {
  const MonthPeriod._(this.firstDay);

  /// The month that contains [day].
  factory MonthPeriod.containing(DateTime day) =>
      MonthPeriod._(DateTime(day.year, day.month));

  /// How far back the person can go: the history of the bank connection has
  /// 12 months, the current one and the 11 before it.
  static const maxMonthsBack = 11;

  /// Day 1 of the month.
  final DateTime firstDay;

  MonthPeriod get previous =>
      MonthPeriod._(DateTime(firstDay.year, firstDay.month - 1));

  MonthPeriod get next =>
      MonthPeriod._(DateTime(firstDay.year, firstDay.month + 1));

  /// The last day of the month.
  DateTime get lastDay => DateTime(firstDay.year, firstDay.month + 1, 0);

  int get daysInMonth => lastDay.day;

  /// Day 1 until the last day. The planning is by month, so it uses this.
  DateRange get wholeMonth => DateRange(from: firstDay, to: lastDay);

  bool isCurrent(DateTime today) =>
      firstDay.year == today.year && firstDay.month == today.month;

  /// How many months this one is before the month of [today].
  int monthsBefore(DateTime today) =>
      (today.year - firstDay.year) * 12 + (today.month - firstDay.month);

  bool canGoPrevious(DateTime today) => monthsBefore(today) < maxMonthsBack;

  /// The home never shows a month that did not start yet.
  bool canGoNext(DateTime today) => monthsBefore(today) > 0;

  /// The days with closed numbers: the whole month when it is over, day 1
  /// until yesterday for the current one, and `null` on day 1 of the current
  /// month, when no day is over yet.
  DateRange? spendingRange(DateTime today) {
    if (!isCurrent(today)) return wholeMonth;
    if (today.day == 1) return null;
    return DateRange(
      from: firstDay,
      to: DateTime(today.year, today.month, today.day - 1),
    );
  }

  @override
  List<Object?> get props => [firstDay];
}
