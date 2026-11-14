import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/widgets/async_state_view.dart';
import 'package:mobile/core/widgets/error_state.dart';
import 'package:mobile/core/widgets/offline_banner.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entries_view_model.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/entries/presentation/widgets/entries_states.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_filter_chips.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_filter_sheet.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_row.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/household/presentation/widgets/scope_selector.dart';
import 'package:mobile/features/transactions/presentation/widgets/transactions_states.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The entries tab: the tabs (planned, reconciled, cancelled), search, who
/// appears, the month, filters and the list. It is read only for now.
///
/// It creates its own ViewModel and loads it. [onOpenDetail] defaults to
/// navigating with the router.
class EntriesView extends StatefulWidget {
  const EntriesView({
    super.key,
    required this.createViewModel,
    this.onOpenDetail,
  });

  final EntriesViewModel Function() createViewModel;
  final ValueChanged<EntryDetailArgs>? onOpenDetail;

  @override
  State<EntriesView> createState() => _EntriesViewState();
}

class _EntriesViewState extends State<EntriesView> {
  /// How close to the end of the list (in pixels) the next page is asked for.
  static const _loadMoreDistance = 300.0;

  late final EntriesViewModel _viewModel = widget.createViewModel();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_viewModel.start());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
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
    final result = await EntryFilterSheet.show(
      context,
      filters: vm.filters,
      accounts: vm.accountList,
      scopeOptions: vm.scopeOptions,
      scope: current,
    );
    if (result == null || !mounted) return;
    await vm.applyFilters(result.filters, scope: result.scope);
  }

  void _openDetail(FinancialEntry entry) {
    final vm = _viewModel;
    final args = EntryDetailArgs(
      entry: entry,
      account: vm.accountOf(entry.accountId),
      owner: vm.memberOf(entry.ownerId),
      ownerColorIndex: vm.memberIndexOf(entry.ownerId),
    );
    final open = widget.onOpenDetail;
    if (open != null) {
      open(args);
    } else {
      unawaited(context.push(AppRoutes.entryDetail, extra: args));
    }
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
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(l10n.navEntries, style: theme.textTheme.titleLarge),
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
      _tabs(l10n),
      TextField(
        controller: _searchController,
        onChanged: vm.setSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.entriesSearchHint,
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
      _monthChips(l10n),
      if (!vm.filters.isEmpty)
        EntryFilterChips(
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

  Widget _tabs(AppLocalizations l10n) {
    final vm = _viewModel;
    String label(String name, EntryStatus status) {
      final count = vm.countOf(status);
      return count == null ? name : '$name $count';
    }

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<EntryStatus>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: EntryStatus.planned,
            label: Text(
              label(l10n.entriesTabPlanned, EntryStatus.planned),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ButtonSegment(
            value: EntryStatus.reconciled,
            label: Text(
              label(l10n.entriesTabReconciled, EntryStatus.reconciled),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ButtonSegment(
            value: EntryStatus.cancelled,
            label: Text(
              label(l10n.entriesTabCancelled, EntryStatus.cancelled),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        selected: {vm.tab},
        onSelectionChanged: (values) => unawaited(vm.selectTab(values.first)),
      ),
    );
  }

  Widget _monthChips(AppLocalizations l10n) {
    final vm = _viewModel;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(l10n.entriesMonthAll),
              selected: vm.month == null,
              onSelected: (_) => unawaited(vm.selectMonth(null)),
            ),
          ),
          for (final month in vm.months)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(_capitalized(DateFormatter.monthShort(month))),
                selected: vm.month == month,
                onSelected: (_) => unawaited(vm.selectMonth(month)),
              ),
            ),
        ],
      ),
    );
  }

  static String _capitalized(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  Widget _countRow(AppLocalizations l10n, ThemeData theme) {
    final vm = _viewModel;
    final total = vm.total;
    return Row(
      children: [
        Expanded(
          child: Text(
            total == null || vm.items.isEmpty
                ? ''
                : l10n.entriesShowing(vm.items.length, total),
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

  /// The body under the controls: skeleton, error, empty, or the entries.
  List<Widget> _list(BuildContext context, AppLocalizations l10n) {
    final vm = _viewModel;
    switch (vm.state) {
      case UiInitial<List<FinancialEntry>>() ||
          UiLoading<List<FinancialEntry>>():
        return const [TransactionsSkeleton()];
      case UiError<List<FinancialEntry>>(:final failure):
        return [
          ErrorState(failure: failure, onRetry: () => unawaited(vm.load())),
        ];
      case UiEmpty<List<FinancialEntry>>():
        return [
          EntriesEmptyCard(
            tab: vm.tab,
            month: vm.month,
            filtered: vm.hasSearchOrFilters,
            onClearAll: _clearAll,
          ),
        ];
      case UiSuccess<List<FinancialEntry>>(:final data):
        return [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < data.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  EntryRow(
                    entry: data[i],
                    today: vm.today,
                    onTap: () => _openDetail(data[i]),
                  ),
                ],
              ],
            ),
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
            Text(l10n.entriesLoadingMore, style: muted),
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
        child: Center(child: Text(l10n.entriesEnd, style: muted)),
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
        Skeleton(height: 40, radius: AppRadius.button),
        SizedBox(height: AppSpacing.sm),
        Skeleton(height: 48, radius: AppRadius.md),
        SizedBox(height: AppSpacing.sm),
        TransactionsSkeleton(),
      ],
    );
  }
}
