import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';

/// The fields of the filter sheet that are typed (and so can be wrong).
enum FilterField { from, to, min, max }

/// Why a typed field was refused.
enum FilterError {
  invalidDate,
  invalidAmount,
  datesOutOfOrder,
  amountsOutOfOrder,
}

/// What the typed fields of the filter sheet became: the values that are
/// valid, and the errors of the ones that are not.
class TransactionFilterFormResult {
  const TransactionFilterFormResult({
    required this.dateFrom,
    required this.dateTo,
    required this.minAmount,
    required this.maxAmount,
    required this.errors,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Decimal? minAmount;
  final Decimal? maxAmount;
  final Map<FilterField, FilterError> errors;

  bool get isValid => errors.isEmpty;
}

/// Checks what was typed in the filter sheet: dates as `dd/mm/aaaa` and
/// amounts like `10,50`. An empty field means "no limit". It is a plain
/// function so it can be tested without a screen.
TransactionFilterFormResult validateTransactionFilterForm({
  required String from,
  required String to,
  required String min,
  required String max,
}) {
  final errors = <FilterField, FilterError>{};

  DateTime? date(String text, FilterField field) {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    final parsed = DateFormatter.parse(clean);
    if (parsed == null) errors[field] = FilterError.invalidDate;
    return parsed;
  }

  Decimal? amount(String text, FilterField field) {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    final parsed = MoneyFormatter.parse(clean);
    if (parsed == null) errors[field] = FilterError.invalidAmount;
    return parsed;
  }

  final dateFrom = date(from, FilterField.from);
  final dateTo = date(to, FilterField.to);
  final minAmount = amount(min, FilterField.min);
  final maxAmount = amount(max, FilterField.max);

  if (dateFrom != null && dateTo != null && dateFrom.isAfter(dateTo)) {
    errors[FilterField.to] = FilterError.datesOutOfOrder;
  }
  if (minAmount != null && maxAmount != null && minAmount > maxAmount) {
    errors[FilterField.max] = FilterError.amountsOutOfOrder;
  }

  return TransactionFilterFormResult(
    dateFrom: dateFrom,
    dateTo: dateTo,
    minAmount: minAmount,
    maxAmount: maxAmount,
    errors: errors,
  );
}
