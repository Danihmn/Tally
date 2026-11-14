import 'package:mobile/features/accounts/data/models/account_balance_dto.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';

extension AccountBalanceDtoMapper on AccountBalanceDto {
  AccountBalance toEntity() => AccountBalance(
    id: id,
    ownerId: userId,
    kind: type == AccountKind.credit.apiValue
        ? AccountKind.credit
        : AccountKind.bank,
    name: name,
    marketingName: marketingName,
    number: number,
    balance: balance,
    credit: switch (credit) {
      final CreditInfoDto info => CreditInfo(
        creditLimit: info.creditLimit,
        availableCreditLimit: info.availableCreditLimit,
        dueDate: info.dueDate,
        closeDate: info.closeDate,
      ),
      null => null,
    },
  );
}
