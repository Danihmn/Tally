import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/widgets/async_state_view.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/household/presentation/viewmodels/users_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/member_palette.dart';
import 'package:mobile/features/household/presentation/widgets/new_user_sheet.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Usuários": the people of the house. Tapping one opens their details; the
/// button adds a person. Nobody can be deleted.
///
/// It creates its own ViewModel and loads it. [onOpenUser] defaults to
/// navigating with the router.
class UsersView extends StatefulWidget {
  const UsersView({super.key, required this.createViewModel, this.onOpenUser});

  final UsersViewModel Function() createViewModel;
  final void Function(Member member)? onOpenUser;

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  late final UsersViewModel _viewModel = widget.createViewModel();

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

  void _open(Member member) {
    final custom = widget.onOpenUser;
    if (custom != null) {
      custom(member);
      return;
    }
    unawaited(context.push(AppRoutes.userDetail, extra: member));
  }

  Future<void> _create() async {
    final saved = await NewUserSheet.show(
      context,
      onSubmit: (draft) async => (await _viewModel.create(draft)).failureOrNull,
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).usersAddedNotice)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.usersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_create()),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.usersNew),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => AsyncStateView<HouseholdProfile>(
            state: _viewModel.profile,
            onRetry: () => unawaited(_viewModel.retry()),
            builder: (context, profile) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.sm,
                AppSpacing.screenGutter,
                // Room for the floating button.
                96,
              ),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < profile.members.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _UserRow(
                          member: profile.members[i],
                          isMe: profile.members[i].id == profile.me.id,
                          color: MemberPalette.colorFor(context, i),
                          onTap: () => _open(profile.members[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.member,
    required this.isMe,
    required this.color,
    required this.onTap,
  });

  final Member member;
  final bool isMe;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = [member.fullName, ?member.email].join(' · ');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Text(
                  member.initial,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EllipsisText(
                      isMe
                          ? l10n.membersYou(member.displayName)
                          : member.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    EllipsisText(
                      sub,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
