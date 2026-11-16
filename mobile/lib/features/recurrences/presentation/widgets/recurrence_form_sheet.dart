import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_type_fields.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/widgets/member_palette.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/presentation/viewmodels/recurrence_form.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Saves the draft. Returns `null` when it worked, or why it did not (the
/// sheet then stays open and shows the failure).
typedef RecurrenceSubmit = Future<Failure?> Function(RecurrenceDraft draft);

/// "Nova recorrência" and "Editar recorrência": the form of a recurrence,
/// with the owner chosen among the people of the house.
class RecurrenceFormSheet extends StatefulWidget {
  const RecurrenceFormSheet({
    super.key,
    required this.onSubmit,
    required this.members,
    this.defaultOwnerId,
    this.initial,
  });

  final RecurrenceSubmit onSubmit;

  /// The people of the house, the logged person first.
  final List<Member> members;

  /// The owner picked at first when [initial] has none (the logged person).
  final String? defaultOwnerId;

  /// The recurrence being edited, or `null` for a new one.
  final Recurrence? initial;

  /// Shows the sheet. The result is `true` when the recurrence was saved.
  static Future<bool?> show(
    BuildContext context, {
    required RecurrenceSubmit onSubmit,
    required List<Member> members,
    String? defaultOwnerId,
    Recurrence? initial,
  }) => showAppBottomSheet<bool>(
    context,
    builder: (context) => RecurrenceFormSheet(
      onSubmit: onSubmit,
      members: members,
      defaultOwnerId: defaultOwnerId,
      initial: initial,
    ),
  );

  @override
  State<RecurrenceFormSheet> createState() => _RecurrenceFormSheetState();
}

class _RecurrenceFormSheetState extends State<RecurrenceFormSheet> {
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _category = TextEditingController(
    text: widget.initial?.category ?? '',
  );
  late final _amount = TextEditingController(
    text: _amountText(widget.initial?.amount),
  );
  late final _day = TextEditingController(
    text: widget.initial?.dueDay?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');

  late String? _ownerId = widget.initial?.ownerId ?? widget.defaultOwnerId;
  late EntryType _type = widget.initial?.type ?? EntryType.expenses;
  late PaymentType? _payment = widget.initial?.paymentType;

  Map<RecurrenceFormField, RecurrenceFormError> _errors = const {};
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
    _day.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = validateRecurrenceForm(
      ownerId: _ownerId,
      description: _description.text,
      type: _type,
      paymentType: _payment,
      category: _category.text,
      amount: _amount.text,
      dueDay: _day.text,
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

  String? _errorText(AppLocalizations l10n, RecurrenceFormField field) =>
      switch (_errors[field]) {
        RecurrenceFormError.required => l10n.formRequired,
        RecurrenceFormError.invalidAmount => l10n.formAmountInvalid,
        RecurrenceFormError.invalidDay => l10n.formDueDayInvalid,
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
                editing ? l10n.recurrenceEditTitle : l10n.recurrenceNew,
                style: theme.textTheme.titleLarge,
              ),
              FilterSectionLabel(l10n.recurrenceFormOwner),
              _OwnerField(
                members: widget.members,
                selectedId: _ownerId,
                error: _errorText(l10n, RecurrenceFormField.owner),
                onChanged: (id) => setState(() => _ownerId = id),
              ),
              FilterSectionLabel(l10n.entryFormDescription),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                decoration: InputDecoration(
                  hintText: l10n.recurrenceFormDescriptionHint,
                  errorText: _errorText(l10n, RecurrenceFormField.description),
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
                error: _errorText(l10n, RecurrenceFormField.amount),
              ),
              FilterSectionLabel(l10n.recurrenceFormDay),
              TextField(
                controller: _day,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  hintText: l10n.recurrenceFormDayExample,
                  helperText: l10n.recurrenceFormDayHint,
                  helperMaxLines: 2,
                  errorText: _errorText(l10n, RecurrenceFormField.dueDay),
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
                      color: theme.colorScheme.error,
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
                      : Text(l10n.recurrenceFormSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Dono": one chip per person of the house, with the color of the person.
class _OwnerField extends StatelessWidget {
  const _OwnerField({
    required this.members,
    required this.selectedId,
    required this.onChanged,
    this.error,
  });

  final List<Member> members;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < members.length; i++)
              ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: MemberPalette.colorFor(context, i),
                  child: Text(
                    members[i].initial,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                label: Text(members[i].displayName),
                selected: members[i].id == selectedId,
                onSelected: (_) => onChanged(members[i].id),
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
