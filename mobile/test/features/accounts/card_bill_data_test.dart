import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/accounts/data/datasources/accounts_remote_data_source.dart';
import 'package:mobile/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';
import 'package:mobile/features/accounts/domain/usecases/get_card_bill.dart';

import '../../support/fake_dio.dart';
import '../../support/fakes.dart';

Map<String, dynamic> bill({List<Object?> transactions = const []}) => {
  'account_id': 'c1',
  'month': '2026-12',
  'total': '30.00',
  'estimated': true,
  'transactions': transactions,
};

Map<String, dynamic> installment() => {
  'id': 't1',
  'date': '2026-11-20T00:00:00Z',
  'description': 'Loja',
  'amount': '30.00',
  'currency_code': 'BRL',
  'type': 'DEBIT',
  'status': 'PENDING',
  'category': null,
  'operation_type': null,
  'installment_number': 1,
  'total_installments': 10,
};

void main() {
  GetCardBill build(FakeHttpAdapter adapter) => GetCardBill(
    AccountsRepositoryImpl(AccountsRemoteDataSource(buildFakeDio(adapter))),
  );

  FakeHttpAdapter answering(Object? body, {int status = 200}) =>
      FakeHttpAdapter((_) => FakeReply(status, body));

  group('GetCardBill', () {
    test('asks_for_the_bill_of_the_card_with_the_month_as_yyyy_mm', () async {
      final adapter = answering(bill());

      await build(adapter)('c1', month: DateTime(2026, 3, 15));

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/bank-accounts/c1/bill');
      expect(request.queryParameters, {'month': '2026-03'});
    });

    test('reads_the_total_and_each_installment', () async {
      final result = await build(
        answering(bill(transactions: [installment()])),
      )('c1', month: DateTime(2026, 12));

      final value = result.valueOrNull!;
      expect(value.month, DateTime(2026, 12));
      expect(value.total, Decimal.parse('30.00'));
      expect(value.estimated, isTrue);
      expect(
        value.items.single,
        CardBillItem(
          id: 't1',
          day: DateTime(2026, 11, 20),
          description: 'Loja',
          amount: Decimal.parse('30.00'),
          isCredit: false,
          isPending: true,
          installmentNumber: 1,
          totalInstallments: 10,
        ),
      );
      expect(value.items.single.installmentLabel, '1/10');
    });

    test('a_refund_comes_as_a_positive_credit', () async {
      final refund = {...installment(), 'type': 'CREDIT', 'amount': '-12.50'};

      final result = await build(answering(bill(transactions: [refund])))(
        'c1',
        month: DateTime(2026, 12),
      );

      final item = result.valueOrNull!.items.single;
      expect(item.isCredit, isTrue);
      expect(item.amount, Decimal.parse('12.50'));
    });

    test('a_bad_month_is_an_unknown_failure', () async {
      final result = await build(answering({...bill(), 'month': 'dezembro'}))(
        'c1',
        month: DateTime(2026, 12),
      );

      expect(result.failureOrNull, const UnknownFailure());
    });

    test('a_404_is_not_found', () async {
      final result = await build(answering({'detail': 'x'}, status: 404))(
        'c1',
        month: DateTime(2026, 12),
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('CardBillItem.installmentLabel', () {
    CardBillItem item({int? number, int? total}) => CardBillItem(
      id: 'x',
      day: DateTime(2026),
      description: null,
      amount: Decimal.one,
      isCredit: false,
      isPending: false,
      installmentNumber: number,
      totalInstallments: total,
    );

    test('a_single_payment_has_no_label', () {
      expect(item().installmentLabel, isNull);
      expect(item(number: 1, total: 1).installmentLabel, isNull);
    });

    test('an_installment_shows_number_and_total', () {
      expect(item(number: 3, total: 10).installmentLabel, '3/10');
    });
  });
}
