import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/widgets/async_state_view.dart';
import 'package:mobile/core/widgets/error_state.dart';
import 'package:mobile/core/widgets/offline_banner.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/household/presentation/widgets/member_palette.dart';
import 'package:mobile/features/household/presentation/widgets/scope_selector.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_args.dart';
import 'package:mobile/features/transactions/presentation/widgets/active_filter_chips.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_day_section.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_filter_sheet.dart';
import 'package:mobile/features/transactions/presentation/widgets/transaction_row.dart';
import 'package:mobile/features/transactions/presentation/widgets/transactions_states.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The transactions tab: search, who appears, filters, the list grouped by day
/// and a detail screen for each transaction.
///
/// It creates its own ViewModel and loads it. [onOpenDetail] and
/// [onOpenAccounts] default to navigating with the router.
class TransactionsView extends StatefulWidget {
  const TransactionsView({
    super.key,
    required this.createViewModel,
    this.onOpenDetail,
    this.onOpenAccounts,
  });

  final TransactionsViewModel Function() createViewModel;
  final ValueChanged<TransactionDetailArgs>? onOpenDetail;
  final VoidCallback? onOpenAccounts;

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  /// How close to the end of the list (in pixels) the next page is asked for.
  static const _loadMoreDistance = 300.0;

  late final TransactionsViewModel _viewModel = widget.createViewModel();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _viewModel.addListener(_syncSearchBox);
    unawaited(_viewModel.start());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _viewModel
      ..removeListener(_syncSearchBox)
      ..dispose();
    super.dispose();
  }

  /// The search text can be cleared from outside (another screen asked for one
  /// account): the box must follow.
  void _syncSearchBox() {
    if (_viewModel.search.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreDistance) {
      unawaited(_viewModel.loadMore());
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _viewModel.clearSearch();
  }

  void _clearAll() {
    _searchController.clear();
    unawaited(_viewModel.clearAll());
  }

  Future<void> _openFilters() async {
    final vm = _viewModel;
    final current = vm.scope;
    if (current == null) return;
    final result = await TransactionFilterSheet.show(
      context,
      filters: vm.filters,
      accounts: vm.accountList,
      scopeOptions: vm.scopeOptions,
      scope: current,
    );
    if (result == null || !mounted) return;
    await vm.applyFilters(result.filters, scope: result.scope);
  }

  void _openDetail(Transaction transaction) {
    final vm = _viewModel;
    final args = TransactionDetailArgs(
      transaction: transaction,
      account: vm.accountOf(transaction.accountId),
      owner: vm.memberOf(transaction.ownerId),
      ownerColorIndex: vm.memberIndexOf(transaction.ownerId),
    );
    final open = widget.onOpenDetail;
    if (open != null) {
      open(args);
    } else {
      unawaited(context.push(AppRoutes.transactionDetail, extra: args));
    }
  }

  void _openAccounts() =>
      (widget.onOpenAccounts ?? () => context.go(AppRoutes.accounts))();

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
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.navTransactions,
              style: theme.textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: l10n.transactionsFilterButton,
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: vm.filters.activeCount > 0,
              label: Text('${vm.filters.activeCount}'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      ScopeSelector(
        options: vm.scopeOptions,
        selected: vm.scope!,
        onSelected: (option) => unawaited(vm.selectScope(option)),
      ),
      TextField(
        controller: _searchController,
        onChanged: vm.setSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.transactionsSearchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: vm.search.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.transactionsClearSearch,
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      if (!vm.filters.isEmpty)
        ActiveFilterChips(
          filters: vm.filters,
          accounts: vm.accountList,
          onRemove: (key) => unawaited(vm.removeFilter(key)),
        ),
      _countRow(l10n, theme),
      ..._list(context, l10n),
    ];

    return Column(
      children: [
        OfflineBanner(failure: vm.inlineFailure),
        Expanded(
          child: RefreshIndicator(
            onRefresh: vm.reload,
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) => children[index],
            ),
          ),
        ),
      ],
    );
  }

  Widget _countRow(AppLocalizations l10n, ThemeData theme) {
    final vm = _viewModel;
    final total = vm.total;
    return Row(
      children: [
        Expanded(
          child: Text(
            total == null || vm.items.isEmpty
                ? ''
                : l10n.transactionsShowing(vm.items.length, total),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => unawaited(vm.reload()),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(l10n.transactionsRefresh),
        ),
      ],
    );
  }

  /// The body under the controls: no bank, skeleton, error, empty, or the days.
  List<Widget> _list(BuildContext context, AppLocalizations l10n) {
    final vm = _viewModel;
    if (vm.hasConnectedBank == false) {
      final scope = vm.scope;
      final who = scope?.member?.firstName ?? l10n.transactionsTheHouse;
      return [NoBankCard(who: who, onSeeAccounts: _openAccounts)];
    }
    switch (vm.state) {
      case UiInitial<List<Transaction>>() || UiLoading<List<Transaction>>():
        return const [TransactionsSkeleton()];
      case UiError<List<Transaction>>(:final failure):
        return [
          ErrorState(failure: failure, onRetry: () => unawaited(vm.load())),
        ];
      case UiEmpty<List<Transaction>>():
        return [
          TransactionsEmptyCard(
            filtered: vm.hasSearchOrFilters,
            onClearAll: _clearAll,
          ),
        ];
      case UiSuccess<List<Transaction>>():
        return [
          for (final group in vm.groups)
            TransactionDaySection(
              group: group,
              today: vm.today,
              rowBuilder: (context, index) {
                final transaction = group.items[index];
                final owner = vm.memberOf(transaction.ownerId);
                return TransactionRow(
                  transaction: transaction,
                  accountName: vm.accountOf(transaction.accountId)?.displayName,
                  ownerInitial: owner?.initial ?? '?',
                  ownerColor: MemberPalette.colorFor(
                    context,
                    vm.memberIndexOf(transaction.ownerId),
                  ),
                  onTap: () => _openDetail(transaction),
                );
              },
            ),
          _footer(l10n),
        ];
    }
  }

  Widget _footer(AppLocalizations l10n) {
    final vm = _viewModel;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (vm.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(l10n.transactionsLoadingMore, style: muted),
          ],
        ),
      );
    }
    if (vm.inlineFailure != null && vm.hasMore) {
      return Center(
        child: Column(
          children: [
            Text(l10n.loadMoreError, style: muted),
            TextButton(
              onPressed: () => unawaited(vm.loadMore()),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (!vm.hasMore && vm.items.length > 12) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(child: Text(l10n.transactionsEnd, style: muted)),
      );
    }
    return const SizedBox.shrink();
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
        SizedBox(height: AppSpacing.sm),
        Skeleton(height: 48, radius: AppRadius.md),
        SizedBox(height: AppSpacing.sm),
        TransactionsSkeleton(),
      ],
    );
  }
}
