import 'package:mobile/features/home/data/models/home_dtos.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/entry_type.dart';
import 'package:mobile/features/home/domain/entities/reconciliation_counts.dart';
import 'package:mobile/features/home/domain/entities/top_expense.dart';
import 'package:mobile/features/home/domain/entities/upcoming_entry.dart';

extension DailyAmountDtoMapper on DailyAmountDto {
  DailyAmount toEntity() => DailyAmount(day: date, amount: total);
}

extension TopExpenseDtoMapper on TopExpenseDto {
  TopExpense toEntity() =>
      TopExpense(date: date, amount: amount, description: description);
}

extension ReconciliationCountsDtoMapper on ReconciliationCountsDto {
  ReconciliationCounts toEntity() => ReconciliationCounts(
    reconciled: reconciled,
    notReconciled: notReconciled,
  );
}

extension UpcomingEntryDtoMapper on UpcomingEntryDto {
  UpcomingEntry toEntity() => UpcomingEntry(
    description: description,
    amount: amount,
    isIncome: type == EntryType.revenues.apiValue,
    category: category,
    dueDate: dueDate,
  );
}
