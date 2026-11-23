import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_call.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/utils/json_parsing.dart';
import 'package:mobile/features/accounts/data/models/account_balance_dto.dart';
import 'package:mobile/features/accounts/data/models/bank_account_dto.dart';
import 'package:mobile/features/accounts/data/models/card_bill_dto.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';

/// Calls the bank accounts endpoints.
class AccountsRemoteDataSource {
  const AccountsRemoteDataSource(this._dio);

  /// The largest page the API accepts. A house has a handful of accounts.
  static const _pageSize = 100;

  final Dio _dio;

  Future<Result<List<BankAccountDto>>> getAccounts() => apiCall(() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.bankAccounts.path,
      queryParameters: {'limit': _pageSize},
    );
    return [
      for (final item in response.data!)
        BankAccountDto.fromJson(item as Map<String, dynamic>),
    ];
  });

  /// The accounts and cards of connected banks with their balance. [userId]
  /// limits it to one person (without it, the whole house).
  Future<Result<List<AccountBalanceDto>>> getBalances({String? userId}) =>
      apiCall(() async {
        final response = await _dio.get<List<dynamic>>(
          ApiEndpoints.accountBalances.path,
          queryParameters: {'user_id': ?userId},
        );
        return [
          for (final item in response.data!)
            AccountBalanceDto.fromJson(item as Map<String, dynamic>),
        ];
      });

  /// The sum of the balances of one kind: the balance of the accounts, or the
  /// open bills of the cards.
  Future<Result<Decimal>> getTotalBalance({
    required AccountKind kind,
    String? userId,
  }) => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.totalAccountBalance.path,
      queryParameters: {'type': kind.apiValue, 'user_id': ?userId},
    );
    return parseDecimal(response.data!['total']);
  });

  /// Changes the "conta salário" settings of a bank account. Only what is
  /// given is sent.
  Future<Result<void>> updateSettings(
    String id, {
    bool? outgoingTransfersAreIncome,
    String? bankCode,
  }) => apiCall(() async {
    await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.updateBankAccount.path.replaceFirst('{id}', id),
      data: {
        'outgoing_transfers_are_income': ?outgoingTransfersAreIncome,
        'bank_code': ?bankCode,
      },
    );
  });

  /// The bill of a card due in [month] (`YYYY-MM`).
  Future<Result<CardBillDto>> getCardBill(
    String accountId, {
    required String month,
  }) => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.creditCardBill.path.replaceFirst('{id}', accountId),
      queryParameters: {'month': month},
    );
    return CardBillDto.fromJson(response.data!);
  });
}
