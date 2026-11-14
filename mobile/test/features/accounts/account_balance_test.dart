import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/accounts/data/mappers/account_balance_mapper.dart';
import 'package:mobile/features/accounts/data/models/account_balance_dto.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';

Map<String, dynamic> item({
  String type = 'BANK',
  Object? balance = '2301.45',
  Object? marketingName = 'Nubank',
  Object? credit,
  String number = '0001/12345-6',
}) => {
  'id': 'a1',
  'user_id': 'm1',
  'type': type,
  'subtype': type == 'CREDIT' ? 'CREDIT_CARD' : 'CHECKING_ACCOUNT',
  'name': 'Conta Corrente',
  'marketing_name': marketingName,
  'number': number,
  'currency_code': 'BRL',
  'balance': balance,
  'updated_at': null,
  'credit': credit,
};

void main() {
  group('AccountBalanceDto', () {
    test('reads_a_bank_account', () {
      final account = AccountBalanceDto.fromJson(item()).toEntity();

      expect(account.id, 'a1');
      expect(account.ownerId, 'm1');
      expect(account.kind, AccountKind.bank);
      expect(account.displayName, 'Nubank');
      expect(account.balance, Decimal.parse('2301.45'));
      expect(account.credit, isNull);
      expect(account.isCreditCard, isFalse);
    });

    test('reads_a_card_with_its_credit_data', () {
      final account = AccountBalanceDto.fromJson(
        item(
          type: 'CREDIT',
          balance: 142.41,
          credit: {
            'credit_limit': '51800.00',
            'available_credit_limit': '51300.00',
            'balance_due_date': '2026-11-17T00:00:00Z',
            'balance_close_date': null,
          },
        ),
      ).toEntity();

      expect(account.kind, AccountKind.credit);
      expect(account.balance, Decimal.parse('142.41'));
      expect(account.credit?.creditLimit, Decimal.parse('51800.00'));
      expect(account.credit?.availableCreditLimit, Decimal.parse('51300.00'));
      expect(account.credit?.dueDate, DateTime.utc(2026, 11, 17));
      expect(account.credit?.closeDate, isNull);
    });

    test('a_missing_balance_and_marketing_name_are_allowed', () {
      final account = AccountBalanceDto.fromJson(
        item(balance: null, marketingName: null),
      ).toEntity();

      expect(account.balance, isNull);
      expect(account.displayName, 'Conta Corrente');
    });

    test('a_missing_required_field_is_a_format_error', () {
      final broken = item()..remove('user_id');

      expect(() => AccountBalanceDto.fromJson(broken), throwsFormatException);
    });
  });

  group('AccountBalance', () {
    test('the_short_number_is_the_last_four_digits', () {
      AccountBalance withNumber(String number) =>
          AccountBalanceDto.fromJson(item(number: number)).toEntity();

      expect(withNumber('5412 7700 0000 1234').shortNumber, '1234');
      expect(withNumber('0001/12345-6').shortNumber, '3456');
      expect(withNumber('98').shortNumber, '98');
      expect(withNumber('abc').shortNumber, 'abc');
    });
  });

  group('CreditInfo.usedShare', () {
    CreditInfo info(String? limit) => CreditInfo(
      creditLimit: limit == null ? null : Decimal.parse(limit),
      availableCreditLimit: null,
      dueDate: null,
      closeDate: null,
    );

    test('is_the_bill_over_the_limit', () {
      expect(info('5000').usedShare(Decimal.parse('1500')), closeTo(0.3, 1e-9));
    });

    test('stays_between_zero_and_one', () {
      expect(info('1000').usedShare(Decimal.parse('2500')), 1.0);
      expect(info('1000').usedShare(Decimal.parse('-50')), 0.0);
    });

    test('is_null_without_a_limit_to_compare_with', () {
      expect(info(null).usedShare(Decimal.parse('100')), isNull);
      expect(info('0').usedShare(Decimal.parse('100')), isNull);
    });
  });
}
