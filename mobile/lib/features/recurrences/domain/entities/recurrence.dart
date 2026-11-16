import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';

/// Whether a recurrence still creates entries. A cancelled one stays in the
/// list ("Canceladas") and can be reactivated.
enum RecurrenceStatus {
  active('ACTIVE'),
  cancelled('CANCELLED');

  const RecurrenceStatus(this.apiValue);

  /// The value the API uses.
  final String apiValue;
}

/// An item that repeats every month (rent, a subscription, a salary). Next
/// month's entries are created from the recurrences.
class Recurrence extends Equatable {
  const Recurrence({
    required this.id,
    required this.description,
    required this.type,
    required this.paymentType,
    required this.amount,
    required this.dueDay,
    required this.category,
    required this.notes,
    this.ownerId,
    this.status = RecurrenceStatus.active,
  });

  final String id;
  final String description;
  final EntryType type;
  final PaymentType? paymentType;

  /// Always positive: the direction is [type].
  final Decimal amount;

  /// The day of the month it is due (1 to 31). A day the month does not have
  /// becomes its last day. `null` when it has no fixed day.
  final int? dueDay;
  final String? category;
  final String? notes;

  /// The person of the house it belongs to. `null` when that person is gone.
  final String? ownerId;
  final RecurrenceStatus status;

  bool get isRevenue => type == EntryType.revenues;

  bool get isCancelled => status == RecurrenceStatus.cancelled;

  @override
  List<Object?> get props => [
    id,
    description,
    type,
    paymentType,
    amount,
    dueDay,
    category,
    notes,
    ownerId,
    status,
  ];
}

/// What the person fills in the recurrence form, to create one or to replace
/// the data of one. The optional fields are `null` when left empty.
class RecurrenceDraft extends Equatable {
  const RecurrenceDraft({
    required this.ownerId,
    required this.description,
    required this.type,
    required this.amount,
    this.paymentType,
    this.dueDay,
    this.category,
    this.notes,
  });

  /// The draft with the same data as [recurrence], to start an edit.
  /// [fallbackOwnerId] is used when the recurrence has no owner anymore.
  factory RecurrenceDraft.fromRecurrence(
    Recurrence recurrence, {
    required String fallbackOwnerId,
  }) => RecurrenceDraft(
    ownerId: recurrence.ownerId ?? fallbackOwnerId,
    description: recurrence.description,
    type: recurrence.type,
    amount: recurrence.amount,
    paymentType: recurrence.paymentType,
    dueDay: recurrence.dueDay,
    category: recurrence.category,
    notes: recurrence.notes,
  );

  /// The person of the house it belongs to.
  final String ownerId;
  final String description;
  final EntryType type;
  final Decimal amount;
  final PaymentType? paymentType;
  final int? dueDay;
  final String? category;
  final String? notes;

  @override
  List<Object?> get props => [
    ownerId,
    description,
    type,
    amount,
    paymentType,
    dueDay,
    category,
    notes,
  ];
}

/// What provisioning a month did.
class ProvisionResult extends Equatable {
  const ProvisionResult({
    required this.referenceMonth,
    required this.created,
    required this.skipped,
  });

  /// The first day of the provisioned month.
  final DateTime referenceMonth;

  /// Entries created now.
  final int created;

  /// Recurrences that already had their entry in that month.
  final int skipped;

  @override
  List<Object?> get props => [referenceMonth, created, skipped];
}
