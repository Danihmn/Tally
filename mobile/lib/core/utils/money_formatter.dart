import 'package:decimal/decimal.dart';

/// The only place where money becomes text (pt-BR) or text becomes money.
///
/// It works on [Decimal] and never goes through `double`.
abstract final class MoneyFormatter {
  /// `R$ 2.301,45`.
  static String format(Decimal value) {
    final negative = value < Decimal.zero;
    final text = 'R\$ ${_plain(value.abs())}';
    return negative ? '-$text' : text;
  }

  /// Number only, without symbol: `2.301,45`.
  static String plain(Decimal value) => _plain(value);

  /// Direction comes from the transaction type, never from the sign of the
  /// amount: `+ R$ 8.900,00` for income, `− R$ 412,37` for expense.
  static String signed(Decimal amount, {required bool isIncome}) {
    final sign = isIncome ? '+' : '−';
    return '$sign R\$ ${_plain(amount.abs())}';
  }

  /// Reads what a person types in a money field: `120,50`, `1.234,56`,
  /// `R$ 10`. Returns `null` when it is not a valid non-negative number.
  static Decimal? parse(String input) {
    var text = input.replaceAll('R\$', '').replaceAll(RegExp(r'\s'), '');
    if (text.isEmpty) return null;
    if (text.contains(',')) {
      // Brazilian style: dots group thousands, the comma is the decimal mark.
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
      text = text.replaceAll('.', '');
    }
    final value = Decimal.tryParse(text);
    if (value == null || value < Decimal.zero) return null;
    return value;
  }

  static String _plain(Decimal absolute) {
    final fixed = absolute.round(scale: 2).toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0];
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(digits[i]);
    }
    return '$grouped,${parts[1]}';
  }
}
