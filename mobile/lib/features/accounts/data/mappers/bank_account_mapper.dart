import 'package:mobile/features/accounts/data/models/bank_account_dto.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';

extension BankAccountDtoMapper on BankAccountDto {
  BankAccount toEntity() => BankAccount(
    id: id,
    ownerId: userId,
    name: name,
    marketingName: marketingName,
    number: number,
    isCreditCard: type == 'CREDIT',
  );
}
