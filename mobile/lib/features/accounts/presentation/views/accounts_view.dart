import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/widgets/async_state_view.dart';
import 'package:mobile/core/widgets/error_state.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/accounts_view_model.dart';
import 'package:mobile/features/accounts/presentation/widgets/account_card.dart';
import 'package:mobile/features/accounts/presentation/widgets/accounts_header.dart';
import 'package:mobile/features/accounts/presentation/widgets/bank_code_dialog.dart';
import 'package:mobile/features/accounts/presentation/widgets/salary_account_confirm_dialog.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/household/presentation/widgets/member_palette.dart';
import 'package:mobile/features/household/presentation/widgets/scope_selector.dart';
import 'package:mobile/features/transactions/domain/transactions_filter_request.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The Contas tab: the total balance, the accounts and the cards with their
/// balance. Tapping one opens the Transações tab filtered by it.
///
/// It creates its own ViewModel and loads it. [filterRequest] carries the
/// chosen account to the Transações tab; [onOpenTransactions] defaults to
/// going to that tab with the router.
class AccountsView extends StatefulWidget {
  const AccountsView({
    super.key,
    required this.createViewModel,
    required this.filterRequest,
    this.onOpenTransactions,
  });

  final AccountsViewModel Function() createViewModel;
  final TransactionsFilterRequest filterRequest;
  final VoidCallback? onOpenTransactions;

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  late final AccountsViewModel _viewModel = widget.createViewModel();

  @override
  void initState() {
    super.initState();
    unawaited(_viewModel.start());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openTransactions(AccountBalance account) {
    widget.filterRequest.requestAccount(account.id);
    final open = widget.onOpenTransactions;
    if (open != null) {
      open();
    } else {
      context.go(AppRoutes.transactions);
    }
  }

  /// Asks for confirmation (the server reclassifies every transfer of the
  /// household), then saves "conta salário". Turning it on sends no bank
  /// code: the server takes it from the account's transfer number. When it
  /// cannot (a 422), the bank code is asked here.
  Future<void> _changeSalaryAccount(
    AccountBalance account,
    bool enabled,
  ) async {
    final confirmed = await showSalaryAccountConfirmDialog(
      context,
      account: account,
      enabling: enabled,
    );
    if (!confirmed || !mounted) return;
    final failure = await _viewModel.setSalaryAccount(
      account,
      enabled: enabled,
    );
    if (!mounted) return;
    if (enabled && failure is ValidationFailure) {
      await _editBankCode(account);
    } else if (failure != null) {
      showFailureSnackBar(context, failure);
    }
  }

  /// Asks the bank code (filled with the current one) and turns it on with it.
  Future<void> _editBankCode(AccountBalance account) async {
    final code = await showBankCodeDialog(context, initial: account.bankCode);
    if (code == null || !mounted) return;
    final failure = await _viewModel.setSalaryAccount(
      account,
      enabled: true,
      bankCode: code,
    );
    if (failure != null && mounted) showFailureSnackBar(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => AsyncStateView<HouseholdProfile>(
            state: _viewModel.profile,
            onRetry: () => unawaited(_viewModel.start()),
            loading: const _FirstLoading(),
            builder: (context, profile) => _content(context),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vm = _viewModel;
    return RefreshIndicator(
      onRefresh: vm.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          Text(l10n.navAccounts, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          ScopeSelector(
            options: vm.scopeOptions,
            selected: vm.scope!,
            onSelected: (option) => unawaited(vm.selectScope(option)),
          ),
          const SizedBox(height: AppSpacing.md),
          AccountsHeader(
            bankTotal: vm.bankTotal,
            cardTotal: vm.cardTotal,
            hasCards: vm.cards.isNotEmpty,
            onRetry: () => unawaited(vm.retryTotals()),
          ),
          const SizedBox(height: AppSpacing.md),
          _tabs(l10n),
          const SizedBox(height: AppSpacing.md),
          ..._list(context, l10n),
        ],
      ),
    );
  }

  Widget _tabs(AppLocalizations l10n) {
    final vm = _viewModel;
    final known = vm.list is UiSuccess<List<AccountBalance>>;
    String label(String name, int count) => known ? '$name $count' : name;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AccountKind>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: AccountKind.bank,
            label: Text(
              label(l10n.accountsTabBanks, vm.banks.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ButtonSegment(
            value: AccountKind.credit,
            label: Text(
              label(l10n.accountsTabCards, vm.cards.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        selected: {vm.tab},
        onSelectionChanged: (values) => vm.selectTab(values.first),
      ),
    );
  }

  /// The body under the tabs: skeleton, error, "no bank", empty tab, or cards.
  List<Widget> _list(BuildContext context, AppLocalizations l10n) {
    final vm = _viewModel;
    switch (vm.list) {
      case UiInitial<List<AccountBalance>>() ||
          UiLoading<List<AccountBalance>>():
        return const [
          Skeleton(height: 168, radius: 20),
          SizedBox(height: AppSpacing.sm),
          Skeleton(height: 168, radius: 20),
        ];
      case UiError<List<AccountBalance>>(:final failure):
        return [
          ErrorState(
            failure: failure,
            onRetry: () => unawaited(vm.retryList()),
          ),
        ];
      case UiEmpty<List<AccountBalance>>():
        final who = vm.scope?.member?.displayName ?? l10n.transactionsTheHouse;
        return [
          _EmptyCard(
            title: l10n.accountsEmptyNoBankTitle(who),
            text: l10n.accountsEmptyNoBankText,
          ),
        ];
      case UiSuccess<List<AccountBalance>>():
        final items = vm.visible;
        if (items.isEmpty) {
          return [
            _EmptyCard(
              title: vm.tab == AccountKind.bank
                  ? l10n.accountsEmptyBanks
                  : l10n.accountsEmptyCards,
              text: l10n.accountsEmptyKindText,
            ),
          ];
        }
        return [
          for (final account in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AccountCard(
                account: account,
                ownerInitial: vm.memberOf(account.ownerId)?.initial ?? '?',
                ownerColor: MemberPalette.colorFor(
                  context,
                  vm.memberIndexOf(account.ownerId),
                ),
                onTap: () => _openTransactions(account),
                saving: vm.isSaving(account.id),
                onSalaryAccountChanged: (enabled) =>
                    unawaited(_changeSalaryAccount(account, enabled)),
                onEditBankCode: () => unawaited(_editBankCode(account)),
              ),
            ),
        ];
    }
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// First load of the whole screen: the profile is not here yet.
class _FirstLoading extends StatelessWidget {
  const _FirstLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: const [
        Skeleton(height: 32),
        SizedBox(height: AppSpacing.sm),
        Skeleton(height: 40, radius: AppRadius.button),
        SizedBox(height: AppSpacing.md),
        Skeleton(height: 112, radius: 24),
        SizedBox(height: AppSpacing.md),
        Skeleton(height: 48, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        Skeleton(height: 168, radius: 20),
      ],
    );
  }
}
