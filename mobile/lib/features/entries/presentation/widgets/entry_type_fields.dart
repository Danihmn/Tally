import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Tipo": expense or revenue. Used by the entry and the recurrence forms.
class EntryTypeField extends StatelessWidget {
  const EntryTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final EntryType value;
  final ValueChanged<EntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionLabel(l10n.entryFormType),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<EntryType>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: EntryType.expenses,
                label: Text(l10n.entryTypeExpense),
              ),
              ButtonSegment(
                value: EntryType.revenues,
                label: Text(l10n.entryTypeRevenue),
              ),
            ],
            selected: {value},
            onSelectionChanged: (values) => onChanged(values.first),
          ),
        ),
      ],
    );
  }
}

/// "Forma de pagamento": debit or credit. It can be left empty: tapping the
/// chosen one again clears it.
class PaymentTypeField extends StatelessWidget {
  const PaymentTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PaymentType? value;
  final ValueChanged<PaymentType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionLabel(l10n.entryFormPayment),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<PaymentType>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              ButtonSegment(
                value: PaymentType.debit,
                label: Text(l10n.entryPayDebit),
              ),
              ButtonSegment(
                value: PaymentType.credit,
                label: Text(l10n.entryPayCredit),
              ),
            ],
            selected: {?value},
            onSelectionChanged: (values) =>
                onChanged(values.isEmpty ? null : values.first),
          ),
        ),
      ],
    );
  }
}
