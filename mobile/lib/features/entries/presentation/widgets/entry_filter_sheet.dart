import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/transaction_filter_form.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// What the person chose in the sheet: the filters and who appears.
class EntryFilterSheetResult {
  const EntryFilterSheetResult({required this.filters, required this.scope});

  final EntryFilters filters;
  final ScopeOption scope;
}

/// "Filtrar lançamentos": the person, the account, the type, the payment, the
/// due date and the amount. There is no filter by category on purpose.
class EntryFilterSheet extends StatefulWidget {
  const EntryFilterSheet({
    super.key,
    required this.filters,
    required this.accounts,
    required this.scopeOptions,
    required this.scope,
  });

  final EntryFilters filters;
  final List<BankAccount> accounts;
  final List<ScopeOption> scopeOptions;
  final ScopeOption scope;

  /// Shows the sheet. The result is `null` when it is closed without applying.
  static Future<EntryFilterSheetResult?> show(
    BuildContext context, {
    required EntryFilters filters,
    required List<BankAccount> accounts,
    required List<ScopeOption> scopeOptions,
    required ScopeOption scope,
  }) => showModalBottomSheet<EntryFilterSheetResult>(
    context: context,
    // Over the tabs, like in the prototype.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => EntryFilterSheet(
      filters: filters,
      accounts: accounts,
      scopeOptions: scopeOptions,
      scope: scope,
    ),
  );

  @override
  State<EntryFilterSheet> createState() => _EntryFilterSheetState();
}

class _EntryFilterSheetState extends State<EntryFilterSheet> {
  late ScopeOption _scope = widget.scope;
  late String? _accountId = widget.filters.accountId;
  late EntryType? _type = widget.filters.type;
  late PaymentType? _payment = widget.filters.paymentType;
  late final _from = TextEditingController(
    text: _dateText(widget.filters.dueFrom),
  );
  late final _to = TextEditingController(text: _dateText(widget.filters.dueTo));
  late final _min = TextEditingController(
    text: _amountText(widget.filters.minAmount),
  );
  late final _max = TextEditingController(
    text: _amountText(widget.filters.maxAmount),
  );
  Map<FilterField, FilterError> _errors = const {};

  static String _dateText(DateTime? date) =>
      date == null ? '' : DateFormatter.date(date);

  /// `10,50`: the thousands dots are left out so the text can be typed over.
  static String _amountText(Decimal? amount) =>
      amount == null ? '' : MoneyFormatter.plain(amount).replaceAll('.', '');

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _scope = widget.scopeOptions.firstWhere(
        (option) => option.kind == ScopeKind.me,
        orElse: () => widget.scope,
      );
      _accountId = null;
      _type = null;
      _payment = null;
      _from.clear();
      _to.clear();
      _min.clear();
      _max.clear();
      _errors = const {};
    });
  }

  void _apply() {
    final form = validateTransactionFilterForm(
      from: _from.text,
      to: _to.text,
      min: _min.text,
      max: _max.text,
    );
    if (!form.isValid) {
      setState(() => _errors = form.errors);
      return;
    }
    Navigator.of(context).pop(
      EntryFilterSheetResult(
        scope: _scope,
        filters: EntryFilters(
          accountId: _accountId,
          type: _type,
          paymentType: _payment,
          dueFrom: form.dateFrom,
          dueTo: form.dateTo,
          minAmount: form.minAmount,
          maxAmount: form.maxAmount,
        ),
      ),
    );
  }

  String? _errorText(AppLocalizations l10n, FilterField field) =>
      switch (_errors[field]) {
        FilterError.invalidDate => l10n.filterDateInvalid,
        FilterError.invalidAmount => l10n.filterAmountInvalid,
        FilterError.datesOutOfOrder => l10n.filterDatesOutOfOrder,
        FilterError.amountsOutOfOrder => l10n.filterAmountsOutOfOrder,
        null => null,
      };

  String _scopeLabel(AppLocalizations l10n, ScopeOption option) =>
      switch (option.kind) {
        ScopeKind.me => l10n.scopeMe,
        ScopeKind.house => l10n.scopeHouse,
        ScopeKind.member => option.member!.firstName,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The house first, like in the prototype, then me and the others.
    final scopeOptions = [
      ...widget.scopeOptions.where((o) => o.kind == ScopeKind.house),
      ...widget.scopeOptions.where((o) => o.kind != ScopeKind.house),
    ];
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.entriesFiltersTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  TextButton(onPressed: _reset, child: Text(l10n.filterReset)),
                ],
              ),
              FilterSectionLabel(l10n.filterPerson),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final option in scopeOptions)
                    ChoiceChip(
                      label: Text(_scopeLabel(l10n, option)),
                      selected: option == _scope,
                      onSelected: (_) => setState(() => _scope = option),
                    ),
                ],
              ),
              FilterSectionLabel(l10n.filterAccount),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: Text(l10n.filterAllAccounts),
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
              FilterSectionLabel(l10n.filterType),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<EntryType?>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: null, label: Text(l10n.filterAll)),
                    ButtonSegment(
                      value: EntryType.expenses,
                      label: Text(l10n.entryTypeExpense),
                    ),
                    ButtonSegment(
                      value: EntryType.revenues,
                      label: Text(l10n.entryTypeRevenue),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (values) =>
                      setState(() => _type = values.first),
                ),
              ),
              FilterSectionLabel(l10n.entriesFilterPayment),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PaymentType?>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: null, label: Text(l10n.filterAll)),
                    ButtonSegment(
                      value: PaymentType.debit,
                      label: Text(l10n.entryPayDebit),
                    ),
                    ButtonSegment(
                      value: PaymentType.credit,
                      label: Text(l10n.entryPayCredit),
                    ),
                  ],
                  selected: {_payment},
                  onSelectionChanged: (values) =>
                      setState(() => _payment = values.first),
                ),
              ),
              FilterSectionLabel(l10n.entriesFilterDue),
              Row(
                children: [
                  Expanded(
                    child: FilterDateField(
                      controller: _from,
                      label: l10n.filterFrom,
                      error: _errorText(l10n, FilterField.from),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilterDateField(
                      controller: _to,
                      label: l10n.filterTo,
                      error: _errorText(l10n, FilterField.to),
                    ),
                  ),
                ],
              ),
              FilterSectionLabel(l10n.filterAmount),
              Row(
                children: [
                  Expanded(
                    child: FilterAmountField(
                      controller: _min,
                      label: l10n.filterMin,
                      hint: l10n.filterAmountHint,
                      error: _errorText(l10n, FilterField.min),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilterAmountField(
                      controller: _max,
                      label: l10n.filterMax,
                      hint: l10n.filterAmountHint,
                      error: _errorText(l10n, FilterField.max),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _apply,
                  child: Text(l10n.filterApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
