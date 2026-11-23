import 'package:mobile/features/accounts/data/models/card_bill_dto.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';

extension CardBillDtoMapper on CardBillDto {
  CardBill toEntity() => CardBill(
    accountId: accountId,
    month: month,
    total: total,
    estimated: estimated,
    items: [for (final t in transactions) t.toEntity()],
  );
}

extension CardBillTransactionDtoMapper on CardBillTransactionDto {
  CardBillItem toEntity() {
    // The API sends days at UTC midnight: the UTC day is the day of the bank.
    final utc = date.toUtc();
    return CardBillItem(
      id: id,
      day: DateTime(utc.year, utc.month, utc.day),
      description: description,
      amount: amount.abs(),
      isCredit: type == 'CREDIT',
      isPending: status == 'PENDING',
      installmentNumber: installmentNumber,
      totalInstallments: totalInstallments,
    );
  }
}
