import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/accounts/domain/repositories/accounts_repository.dart';

/// Turns the "conta salário" setting of a bank account on or off.
///
/// When it is on, the TEDs the account sends to the owner's other accounts
/// count as received money (the bank does not show the salary coming in).
class UpdateAccountSettings {
  const UpdateAccountSettings(this._repository);

  final AccountsRepository _repository;

  Future<Result<void>> call(
    String accountId, {
    bool? outgoingTransfersAreIncome,
    String? bankCode,
  }) => _repository.updateSettings(
    accountId,
    outgoingTransfersAreIncome: outgoingTransfersAreIncome,
    bankCode: bankCode,
  );
}
