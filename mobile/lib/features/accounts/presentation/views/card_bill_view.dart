import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/core/widgets/error_state.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/card_bill_view_model.dart';
import 'package:mobile/features/accounts/presentation/views/card_bill_args.dart';
import 'package:mobile/features/home/presentation/widgets/month_selector.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The bill of one credit card for one due month, with the arrows to change
/// the month. It opens at the bill due next month.
class CardBillView extends StatelessWidget {
  const CardBillView({
    super.key,
    required this.args,
    required this.createViewModel,
  });

  /// `null` when the screen was opened without the card (for example after
  /// the app was restored). It then says so and goes back to the list.
  final CardBillArgs? args;
  final CardBillViewModel Function(String accountId) createViewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final args = this.args;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          args == null ? l10n.cardBillTitle : args.account.displayName,
        ),
      ),
      body: args == null
          ? EmptyState(
              icon: Icons.credit_card_outlined,
              title: l10n.cardBillMissing,
              action: OutlinedButton(
                onPressed: () => context.go(AppRoutes.accounts),
                child: Text(l10n.detailBack),
              ),
            )
          : _Content(createViewModel: () => createViewModel(args.account.id)),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content({required this.createViewModel});

  final CardBillViewModel Function() createViewModel;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  late final CardBillViewModel _viewModel = widget.createViewModel();

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final vm = _viewModel;
        return RefreshIndicator(
          onRefresh: vm.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            children: [
              MonthSelector(
                month: vm.month,
                canGoPrevious: true,
                canGoNext: true,
                onPrevious: () => unawaited(vm.previousMonth()),
                onNext: () => unawaited(vm.nextMonth()),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._body(context, vm),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, CardBillViewModel vm) {
    switch (vm.state) {
      case UiInitial<CardBill>() ||
          UiLoading<CardBill>() ||
          UiEmpty<CardBill>():
        return const [
          Skeleton(height: 112, radius: 24),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 56),
          SizedBox(height: AppSpacing.xs),
          Skeleton(height: 56),
        ];
      case UiError<CardBill>(:final failure):
        return [
          ErrorState(failure: failure, onRetry: () => unawaited(vm.load())),
        ];
      case UiSuccess<CardBill>(:final data):
        return [
          _TotalCard(bill: data),
          const SizedBox(height: AppSpacing.md),
          if (data.items.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: AppLocalizations.of(context).cardBillEmpty,
            )
          else
            for (final item in data.items) _ItemTile(item: item),
        ];
    }
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.bill});

  final CardBill bill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cardBillTotalLabel, style: muted),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              MoneyFormatter.format(bill.total),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(l10n.cardBillCount(bill.items.length), style: muted),
            if (bill.estimated) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.cardBillEstimated, style: muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final CardBillItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = TallyColors.of(context);
    final description = item.description?.trim();
    final installment = item.installmentLabel;
    final details = [
      DateFormatter.dayMonth(item.day),
      if (installment != null) l10n.cardBillInstallment(installment),
      if (item.isPending) l10n.cardBillPending,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        description == null || description.isEmpty ? '—' : description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(details),
      trailing: Text(
        item.isCredit
            ? MoneyFormatter.signed(item.amount, isIncome: true)
            : MoneyFormatter.format(item.amount),
        style: theme.textTheme.titleSmall?.copyWith(
          color: item.isCredit ? colors.income : null,
        ),
      ),
    );
  }
}
