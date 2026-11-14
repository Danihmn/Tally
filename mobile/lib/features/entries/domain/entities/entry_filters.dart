import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// Which filter a chip of the list stands for.
enum EntryFilterKey {
  account,
  type,
  paymentType,
  dueFrom,
  dueTo,
  minAmount,
  maxAmount,
}

/// What the person chose in the filter sheet. `null` means "do not filter by
/// it". The tab (status), the month, the search text and the person have their
/// own controls, so they are not here.
class EntryFilters extends Equatable {
  const EntryFilters({
    this.accountId,
    this.type,
    this.paymentType,
    this.dueFrom,
    this.dueTo,
    this.minAmount,
    this.maxAmount,
  });

  final String? accountId;
  final EntryType? type;
  final PaymentType? paymentType;

  /// Whole days, both inclusive.
  final DateTime? dueFrom;
  final DateTime? dueTo;
  final Decimal? minAmount;
  final Decimal? maxAmount;

  /// The filter keys in use, in the order the chips show them.
  List<EntryFilterKey> get activeKeys => [
    if (accountId != null) EntryFilterKey.account,
    if (type != null) EntryFilterKey.type,
    if (paymentType != null) EntryFilterKey.paymentType,
    if (dueFrom != null) EntryFilterKey.dueFrom,
    if (dueTo != null) EntryFilterKey.dueTo,
    if (minAmount != null) EntryFilterKey.minAmount,
    if (maxAmount != null) EntryFilterKey.maxAmount,
  ];

  int get activeCount => activeKeys.length;

  bool get isEmpty => activeCount == 0;

  /// The same filters without one of them (the chip was removed).
  EntryFilters without(EntryFilterKey key) => EntryFilters(
    accountId: key == EntryFilterKey.account ? null : accountId,
    type: key == EntryFilterKey.type ? null : type,
    paymentType: key == EntryFilterKey.paymentType ? null : paymentType,
    dueFrom: key == EntryFilterKey.dueFrom ? null : dueFrom,
    dueTo: key == EntryFilterKey.dueTo ? null : dueTo,
    minAmount: key == EntryFilterKey.minAmount ? null : minAmount,
    maxAmount: key == EntryFilterKey.maxAmount ? null : maxAmount,
  );

  @override
  List<Object?> get props => [
    accountId,
    type,
    paymentType,
    dueFrom,
    dueTo,
    minAmount,
    maxAmount,
  ];
}
