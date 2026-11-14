import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/transaction_filter_form.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// What the filter sheet gives back: the filters and who appears.
class TransactionFilterSheetResult {
  const TransactionFilterSheetResult({
    required this.filters,
    required this.scope,
  });

  final TransactionFilters filters;
  final ScopeOption scope;
}

enum _DirectionChoice { all, debit, credit }

enum _StatusChoice { all, posted, pending }

/// "Filtrar transações": the person, the account, the period, the type, the
/// status and the amount. There is no filter by category on purpose.
class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.filters,
    required this.accounts,
    required this.scopeOptions,
    required this.scope,
  });

  final TransactionFilters filters;
  final List<BankAccount> accounts;
  final List<ScopeOption> scopeOptions;
  final ScopeOption scope;

  /// Shows the sheet. The result is `null` when it is closed without applying.
  static Future<TransactionFilterSheetResult?> show(
    BuildContext context, {
    required TransactionFilters filters,
    required List<BankAccount> accounts,
    required List<ScopeOption> scopeOptions,
    required ScopeOption scope,
  }) => showModalBottomSheet<TransactionFilterSheetResult>(
    context: context,
    // Over the tabs, like in the prototype.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => TransactionFilterSheet(
      filters: filters,
      accounts: accounts,
      scopeOptions: scopeOptions,
      scope: scope,
    ),
  );

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late ScopeOption _scope = widget.scope;
  late String? _accountId = widget.filters.accountId;
  late _DirectionChoice _direction = switch (widget.filters.direction) {
    TransactionDirection.debit => _DirectionChoice.debit,
    TransactionDirection.credit => _DirectionChoice.credit,
    null => _DirectionChoice.all,
  };
  late _StatusChoice _status = switch (widget.filters.status) {
    TransactionStatus.posted => _StatusChoice.posted,
    TransactionStatus.pending => _StatusChoice.pending,
    null => _StatusChoice.all,
  };
  late final _from = TextEditingController(
    text: _dateText(widget.filters.dateFrom),
  );
  late final _to = TextEditingController(
    text: _dateText(widget.filters.dateTo),
  );
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
      _direction = _DirectionChoice.all;
      _status = _StatusChoice.all;
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
      TransactionFilterSheetResult(
        scope: _scope,
        filters: TransactionFilters(
          accountId: _accountId,
          direction: switch (_direction) {
            _DirectionChoice.all => null,
            _DirectionChoice.debit => TransactionDirection.debit,
            _DirectionChoice.credit => TransactionDirection.credit,
          },
          status: switch (_status) {
            _StatusChoice.all => null,
            _StatusChoice.posted => TransactionStatus.posted,
            _StatusChoice.pending => TransactionStatus.pending,
          },
          dateFrom: form.dateFrom,
          dateTo: form.dateTo,
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
                  Text(l10n.filtersTitle, style: theme.textTheme.titleLarge),
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
              FilterSectionLabel(l10n.filterPeriod),
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
              FilterSectionLabel(l10n.filterType),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_DirectionChoice>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _DirectionChoice.all,
                      label: Text(l10n.filterAll),
                    ),
                    ButtonSegment(
                      value: _DirectionChoice.debit,
                      label: Text(l10n.filterDebit),
                    ),
                    ButtonSegment(
                      value: _DirectionChoice.credit,
                      label: Text(l10n.filterCredit),
                    ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (values) =>
                      setState(() => _direction = values.first),
                ),
              ),
              FilterSectionLabel(l10n.filterStatus),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_StatusChoice>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _StatusChoice.all,
                      label: Text(l10n.filterAll),
                    ),
                    ButtonSegment(
                      value: _StatusChoice.posted,
                      label: Text(l10n.transactionPosted),
                    ),
                    ButtonSegment(
                      value: _StatusChoice.pending,
                      label: Text(l10n.transactionPending),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: (values) =>
                      setState(() => _status = values.first),
                ),
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
