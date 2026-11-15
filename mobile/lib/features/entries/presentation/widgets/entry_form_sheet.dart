import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entry_form.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_type_fields.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Saves the draft. Returns `null` when it worked, or why it did not (the
/// sheet then stays open and shows the failure).
typedef EntrySubmit = Future<Failure?> Function(EntryDraft draft);

/// "Novo lançamento" and "Editar lançamento": the form of an entry. The owner
/// is the logged person, so it is not asked.
class EntryFormSheet extends StatefulWidget {
  const EntryFormSheet({
    super.key,
    required this.accounts,
    required this.onSubmit,
    required this.now,
    this.initial,
  });

  final List<BankAccount> accounts;
  final EntrySubmit onSubmit;

  /// Today. Decides which months are offered.
  final DateTime now;

  /// The entry being edited, or `null` for a new one.
  final FinancialEntry? initial;

  /// Shows the sheet. The result is `true` when the entry was saved.
  static Future<bool?> show(
    BuildContext context, {
    required List<BankAccount> accounts,
    required EntrySubmit onSubmit,
    FinancialEntry? initial,
    DateTime? now,
  }) => showAppBottomSheet<bool>(
    context,
    builder: (context) => EntryFormSheet(
      accounts: accounts,
      onSubmit: onSubmit,
      initial: initial,
      now: now ?? DateTime.now(),
    ),
  );

  @override
  State<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<EntryFormSheet> {
  /// Months before and after the current one that can be chosen.
  static const _monthsBefore = 1;
  static const _monthsAfter = 6;

  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _category = TextEditingController(
    text: widget.initial?.category ?? '',
  );
  late final _amount = TextEditingController(
    text: _amountText(widget.initial?.amount),
  );
  late final _due = TextEditingController(
    text: widget.initial?.dueDate == null
        ? ''
        : DateFormatter.date(widget.initial!.dueDate!),
  );
  late final _current = TextEditingController(
    text: widget.initial?.installmentNumber?.toString() ?? '',
  );
  late final _total = TextEditingController(
    text: widget.initial?.installmentTotal?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');

  late EntryType _type = widget.initial?.type ?? EntryType.expenses;
  late PaymentType? _payment = widget.initial?.paymentType;
  late String? _accountId = widget.initial?.accountId;
  late DateTime _month =
      widget.initial?.referenceMonth ??
      DateTime(widget.now.year, widget.now.month);

  Map<EntryFormField, EntryFormError> _errors = const {};
  bool _submitting = false;
  Failure? _failure;

  /// `1500,00`: the thousands dots are left out so the text can be typed over.
  static String _amountText(Decimal? amount) =>
      amount == null ? '' : MoneyFormatter.plain(amount).replaceAll('.', '');

  @override
  void dispose() {
    _description.dispose();
    _category.dispose();
    _amount.dispose();
    _due.dispose();
    _current.dispose();
    _total.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// The months with a chip, in order. The month of the entry being edited is
  /// always there, even when it is far from today.
  List<DateTime> get _months {
    final base = DateTime(widget.now.year, widget.now.month);
    final months = [
      for (var i = -_monthsBefore; i <= _monthsAfter; i++)
        DateTime(base.year, base.month + i),
    ];
    final own = DateTime(_month.year, _month.month);
    if (!months.contains(own)) {
      months
        ..add(own)
        ..sort();
    }
    return months;
  }

  String _monthLabel(DateTime month) {
    final short = DateFormatter.monthShort(month);
    final text = '${short[0].toUpperCase()}${short.substring(1)}';
    return month.year == widget.now.year ? text : '$text ${month.year}';
  }

  Future<void> _submit() async {
    final result = validateEntryForm(
      description: _description.text,
      type: _type,
      paymentType: _payment,
      category: _category.text,
      amount: _amount.text,
      referenceMonth: _month,
      due: _due.text,
      accountId: _accountId,
      installmentCurrent: _current.text,
      installmentTotal: _total.text,
      notes: _notes.text,
    );
    if (!result.isValid) {
      setState(() => _errors = result.errors);
      return;
    }
    setState(() {
      _errors = const {};
      _failure = null;
      _submitting = true;
    });
    final failure = await widget.onSubmit(result.draft!);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _failure = failure;
    });
  }

  String? _errorText(AppLocalizations l10n, EntryFormField field) =>
      switch (_errors[field]) {
        EntryFormError.required => l10n.formRequired,
        EntryFormError.invalidAmount => l10n.formAmountInvalid,
        EntryFormError.invalidDate => l10n.filterDateInvalid,
        EntryFormError.invalidInstallments => l10n.formInstallmentsInvalid,
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final editing = widget.initial != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? l10n.entryEditTitle : l10n.entryNew,
                style: theme.textTheme.titleLarge,
              ),
              FilterSectionLabel(l10n.entryFormDescription),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                decoration: InputDecoration(
                  hintText: l10n.entryFormDescriptionHint,
                  errorText: _errorText(l10n, EntryFormField.description),
                ),
              ),
              EntryTypeField(
                value: _type,
                onChanged: (value) => setState(() => _type = value),
              ),
              PaymentTypeField(
                value: _payment,
                onChanged: (value) => setState(() => _payment = value),
              ),
              FilterSectionLabel(l10n.entryFormCategory),
              TextField(
                controller: _category,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                decoration: InputDecoration(
                  hintText: l10n.entryFormCategoryHint,
                  helperText: l10n.formOptional,
                ),
              ),
              FilterSectionLabel(l10n.entryFormAmount),
              FilterAmountField(
                controller: _amount,
                label: l10n.entryFormAmount,
                hint: l10n.filterAmountHint,
                error: _errorText(l10n, EntryFormField.amount),
              ),
              FilterSectionLabel(l10n.entryFormMonth),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final month in _months)
                    ChoiceChip(
                      label: Text(_monthLabel(month)),
                      selected:
                          month.year == _month.year &&
                          month.month == _month.month,
                      onSelected: (_) => setState(() => _month = month),
                    ),
                ],
              ),
              FilterSectionLabel(l10n.entryFormDue),
              FilterDateField(
                controller: _due,
                label: l10n.entryFormDue,
                error: _errorText(l10n, EntryFormField.due),
              ),
              FilterSectionLabel(l10n.entryFormAccount),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: Text(l10n.entryFormNoAccount),
                    selected: _accountId == null,
                    onSelected: (_) => setState(() => _accountId = null),
                  ),
                  for (final account in widget.accounts)
                    ChoiceChip(
                      label: Text(account.displayName),
                      selected: _accountId == account.id,
                      onSelected: (_) =>
                          setState(() => _accountId = account.id),
                    ),
                ],
              ),
              FilterSectionLabel(l10n.entryFormInstallments),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _current,
                      label: l10n.entryFormInstallmentCurrent,
                      invalid: _errors[EntryFormField.installments] != null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _NumberField(
                      controller: _total,
                      label: l10n.entryFormInstallmentTotal,
                      invalid: _errors[EntryFormField.installments] != null,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  _errorText(l10n, EntryFormField.installments) ??
                      l10n.entryFormInstallmentsHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _errors[EntryFormField.installments] == null
                        ? scheme.onSurfaceVariant
                        : scheme.error,
                  ),
                ),
              ),
              FilterSectionLabel(l10n.entryFormNotes),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                decoration: InputDecoration(
                  hintText: l10n.entryFormNotesHint,
                  helperText: l10n.formOptional,
                ),
              ),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    failureMessage(l10n, _failure!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.entryFormSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A whole number typed with the digits keyboard.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.invalid,
  });

  final TextEditingController controller;
  final String label;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(
        labelText: label,
        error: invalid ? const SizedBox.shrink() : null,
      ),
    );
  }
}
