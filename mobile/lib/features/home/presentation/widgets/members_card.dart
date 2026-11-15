import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/money_formatter.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/home/domain/entities/spending_by_member.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/widgets/member_palette.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// What each person of the house spent: a bar split by person, and a row
/// for each one.
class MembersCard extends StatelessWidget {
  const MembersCard({
    super.key,
    required this.spending,
    required this.members,
    required this.meId,
  });

  final SpendingByMember spending;

  /// Everybody of the house, in the order that gives each one a color.
  final List<Member> members;
  final String meId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color colorOf(Member member) => MemberPalette.colorFor(
      context,
      members.indexWhere((m) => m.id == member.id).clamp(0, members.length),
    );

    final withSpending = [
      for (final item in spending.items)
        if (spending.shareOf(item) > 0) item,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.membersTitle, style: theme.textTheme.titleMedium),
                Text(
                  l10n.membersCount(spending.items.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                key: const Key('membersSplitBar'),
                height: 14,
                child: Row(
                  // Without this the empty colored boxes shrink to no height.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in withSpending)
                      Expanded(
                        flex: (spending.shareOf(item) * 1000).round().clamp(
                          1,
                          1000,
                        ),
                        child: ColoredBox(color: colorOf(item.member)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in spending.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colorOf(item.member)
                          .withValues(alpha: 0.18),
                      child: Text(
                        item.member.initial,
                        style: TextStyle(color: colorOf(item.member)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: EllipsisText(
                                  item.member.id == meId
                                      ? l10n.membersYou(item.member.displayName)
                                      : item.member.displayName,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              EllipsisText(
                                MoneyFormatter.format(item.amount),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: spending.shareOf(item),
                                    minHeight: 8,
                                    color: colorOf(item.member),
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${(spending.shareOf(item) * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
