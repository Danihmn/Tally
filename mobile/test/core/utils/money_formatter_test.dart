import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/money_formatter.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('MoneyFormatter.format', () {
    test('formats_with_symbol_thousands_dot_and_decimal_comma', () {
      expect(MoneyFormatter.format(d('2301.45')), r'R$ 2.301,45');
      expect(MoneyFormatter.format(d('1234567.8')), r'R$ 1.234.567,80');
      expect(MoneyFormatter.format(d('0')), r'R$ 0,00');
      expect(MoneyFormatter.format(d('999')), r'R$ 999,00');
    });

    test('puts_the_minus_sign_before_the_symbol', () {
      expect(MoneyFormatter.format(d('-412.37')), r'-R$ 412,37');
    });

    test('rounds_to_two_decimals_without_float_errors', () {
      expect(MoneyFormatter.plain(d('0.1') + d('0.2')), '0,30');
      expect(MoneyFormatter.plain(d('10.005')), '10,01');
    });
  });

  group('MoneyFormatter.signed', () {
    test('direction_comes_from_the_type_not_from_the_amount_sign', () {
      expect(
        MoneyFormatter.signed(d('-412.37'), isIncome: false),
        '− R\$ 412,37',
      );
      expect(
        MoneyFormatter.signed(d('412.37'), isIncome: false),
        '− R\$ 412,37',
      );
      expect(
        MoneyFormatter.signed(d('8900'), isIncome: true),
        r'+ R$ 8.900,00',
      );
    });
  });

  group('MoneyFormatter.parse', () {
    test('reads_brazilian_typed_values', () {
      expect(MoneyFormatter.parse('120,50'), d('120.50'));
      expect(MoneyFormatter.parse('1.234,56'), d('1234.56'));
      expect(MoneyFormatter.parse(r'R$ 10'), d('10'));
      expect(MoneyFormatter.parse('1.234'), d('1234'));
      expect(MoneyFormatter.parse('12.5'), d('12.5'));
    });

    test('returns_null_for_invalid_or_negative_input', () {
      expect(MoneyFormatter.parse(''), isNull);
      expect(MoneyFormatter.parse('abc'), isNull);
      expect(MoneyFormatter.parse('0,0x'), isNull);
      expect(MoneyFormatter.parse('-5'), isNull);
    });
  });
}
