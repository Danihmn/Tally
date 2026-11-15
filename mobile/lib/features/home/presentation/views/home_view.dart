import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/widgets/async_state_view.dart';
import 'package:mobile/core/widgets/offline_banner.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/home/domain/entities/spending_summary.dart';
import 'package:mobile/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:mobile/features/home/presentation/widgets/ask_tally_button.dart';
import 'package:mobile/features/home/presentation/widgets/attention_card.dart';
import 'package:mobile/features/home/presentation/widgets/daily_spending_card.dart';
import 'package:mobile/features/home/presentation/widgets/empty_spend_card.dart';
import 'package:mobile/features/home/presentation/widgets/home_header.dart';
import 'package:mobile/features/home/presentation/widgets/home_skeletons.dart';
import 'package:mobile/features/home/presentation/widgets/members_card.dart';
import 'package:mobile/features/home/presentation/widgets/month_selector.dart';
import 'package:mobile/features/home/presentation/widgets/planning_card.dart';
import 'package:mobile/features/home/presentation/widgets/summary_section.dart';
import 'package:mobile/features/home/presentation/widgets/top_expenses_card.dart';
import 'package:mobile/features/home/presentation/widgets/upcoming_card.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/household/presentation/widgets/scope_selector.dart';

/// Opens the settings sheet from [context]. [onLogout] ends the session; the
/// sheet calls it after it closes.
typedef OpenSettings = void Function(
  BuildContext context, {
  required VoidCallback onLogout,
});

/// The home: the numbers of the month for one person or for the whole house.
///
/// It creates its own ViewModel and loads it. [onOpenChat] and [onOpenEntries]
/// default to going to those tabs. [onOpenSettings] opens the settings from the
/// avatar menu.
class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.createViewModel,
    required this.onOpenSettings,
    this.onOpenChat,
    this.onOpenEntries,
  });

  final HomeViewModel Function() createViewModel;
  final OpenSettings onOpenSettings;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenEntries;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _viewModel = widget.createViewModel();

  @override
  void initState() {
    super.initState();
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openChat() => (widget.onOpenChat ?? () => context.go(AppRoutes.chat))();

  void _openEntries() =>
      (widget.onOpenEntries ?? () => context.go(AppRoutes.entries))();

  /// One section of the home, with its own loading and error.
  Widget _section<T>({
    required UiState<T> state,
    required HomeSection section,
    required Widget loading,
    required Widget Function(BuildContext context, T data) builder,
  }) => AsyncStateView<T>(
    state: state,
    onRetry: () => unawaited(_viewModel.retry(section)),
    loading: loading,
    builder: builder,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => AsyncStateView<HouseholdProfile>(
            state: _viewModel.profile,
            onRetry: () => unawaited(_viewModel.load()),
            loading: const _HomeLoading(),
            builder: _content,
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, HouseholdProfile profile) {
    final vm = _viewModel;
    final summaryState = vm.summary;

    final children = <Widget>[
      HomeHeader(
        name: profile.me.displayName,
        initial: profile.me.initial,
        onRefresh: () => unawaited(vm.refresh()),
        onOpenSettings: () => widget.onOpenSettings(
          context,
          onLogout: () => unawaited(vm.logout()),
        ),
      ),
      ScopeSelector(
        options: vm.scopeOptions,
        selected: vm.scope!,
        onSelected: (option) => unawaited(vm.selectScope(option)),
      ),
      MonthSelector(
        month: vm.period.firstDay,
        canGoPrevious: vm.canGoPrevious,
        canGoNext: vm.canGoNext,
        onPrevious: () => unawaited(vm.goToPreviousMonth()),
        onNext: () => unawaited(vm.goToNextMonth()),
      ),
      AskTallyButton(onPressed: _openChat),
      _section<SpendingSummary>(
        state: summaryState,
        section: HomeSection.summary,
        loading: const SummarySkeleton(),
        builder: (context, summary) => SummarySection(
          summary: summary,
          month: vm.period.firstDay,
          isCurrentMonth: vm.period.isCurrent(vm.today),
          lastClosedDay: vm.lastClosedDay,
        ),
      ),
      _section(
        state: vm.planning,
        section: HomeSection.planning,
        loading: const CardSkeleton(height: 150),
        builder: (context, progress) => Column(
          children: [
            PlanningCard(progress: progress, month: vm.period.firstDay),
            if (progress.notReconciledCount > 0) ...[
              const SizedBox(height: AppSpacing.md),
              AttentionCard(unreconciledCount: progress.notReconciledCount),
            ],
          ],
        ),
      ),
      ..._spendingDetails(vm, profile, summaryState),
      _section(
        state: vm.upcoming,
        section: HomeSection.upcoming,
        loading: const CardSkeleton(height: 200),
        builder: (context, entries) => UpcomingCard(
          entries: entries,
          today: vm.today,
          onSeeAll: _openEntries,
        ),
      ),
    ];

    return Column(
      children: [
        OfflineBanner(failure: vm.networkFailure),
        Expanded(
          child: RefreshIndicator(
            onRefresh: vm.refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, index) => children[index],
            ),
          ),
        ),
      ],
    );
  }

  /// The cards that only make sense when something was spent: by person, by
  /// day and the biggest expenses. Without spending there is one empty card.
  List<Widget> _spendingDetails(
    HomeViewModel vm,
    HouseholdProfile profile,
    UiState<SpendingSummary> summaryState,
  ) {
    switch (summaryState) {
      case UiInitial<SpendingSummary>() || UiLoading<SpendingSummary>():
        return const [CardSkeleton(height: 150), CardSkeleton(height: 240)];
      case UiSuccess<SpendingSummary>(:final data) when data.hasSpending:
        return [
          if (vm.showsByMember)
            _section(
              state: vm.byMember,
              section: HomeSection.byMember,
              loading: const CardSkeleton(height: 150),
              builder: (context, spending) => MembersCard(
                spending: spending,
                members: profile.members,
                meId: profile.me.id,
              ),
            ),
          _section(
            state: vm.daily,
            section: HomeSection.daily,
            loading: const CardSkeleton(height: 200),
            builder: (context, days) => DailySpendingCard(
              days: days,
              period: vm.period,
              lastClosedDay: vm.lastClosedDay,
              average: data.averagePerDay,
            ),
          ),
          _section(
            state: vm.topExpenses,
            section: HomeSection.topExpenses,
            loading: const CardSkeleton(height: 240),
            builder: (context, expenses) => TopExpensesCard(expenses: expenses),
          ),
        ];
      case UiSuccess<SpendingSummary>() || UiEmpty<SpendingSummary>():
        return const [EmptySpendCard()];
      case UiError<SpendingSummary>():
        // The summary card already shows the error with its retry button.
        return const [];
    }
  }
}

/// First load of the whole home: the profile is not here yet.
class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: const [
        Skeleton(height: 44),
        SizedBox(height: AppSpacing.md),
        Skeleton(height: 40, radius: AppRadius.button),
        SizedBox(height: AppSpacing.md),
        SummarySkeleton(),
        SizedBox(height: AppSpacing.md),
        CardSkeleton(height: 150),
        SizedBox(height: AppSpacing.md),
        CardSkeleton(height: 240),
      ],
    );
  }
}
