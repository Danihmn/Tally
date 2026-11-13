import 'package:mobile/features/transactions/data/models/transaction_dto.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';

extension TransactionDtoMapper on TransactionDto {
  Transaction toEntity() => Transaction(
    id: id,
    accountId: bankAccountId,
    ownerId: userId,
    date: date,
    description: description,
    amount: amount,
    direction: type == TransactionDirection.credit.apiValue
        ? TransactionDirection.credit
        : TransactionDirection.debit,
    status: status == TransactionStatus.pending.apiValue
        ? TransactionStatus.pending
        : TransactionStatus.posted,
    category: category,
    categoryId: categoryId,
    merchantName: merchantName,
    balance: balance,
  );
}
