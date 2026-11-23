import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';

/// Loads the bill of a credit card that is due in one month.
class GetCardBill {
  const GetCardBill(this._repository);

  final AccountsRepository _repository;

  /// [month] is any day of the due month.
  Future<Result<CardBill>> call(String accountId, {required DateTime month}) =>
      _repository.getCardBill(accountId, month: month);
}
