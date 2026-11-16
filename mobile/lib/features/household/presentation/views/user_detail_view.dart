import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/presentation/viewmodels/users_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/edit_user_sheet.dart';
import 'package:mobile/features/household/presentation/widgets/password_sheet.dart';
import 'package:mobile/features/household/presentation/widgets/pluggy_credentials_sheet.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The details of one person of the house, with the buttons to edit their
/// data, their password and their Pluggy credentials (each a sheet of its own).
///
/// [member] is what the list handed over, or `null` when the screen was opened
/// without it. It creates its own ViewModel and reads the up-to-date person
/// from it, so an edit shows right away.
class UserDetailView extends StatefulWidget {
  const UserDetailView({
    super.key,
    required this.createViewModel,
    required this.member,
  });

  final UsersViewModel Function() createViewModel;
  final Member? member;

  @override
  State<UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends State<UserDetailView> {
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

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(Member member) async {
    final saved = await EditUserSheet.show(
      context,
      member: member,
      onSubmit: (changes) async =>
          (await _viewModel.update(member.id, changes)).failureOrNull,
    );
    if (saved != true || !mounted) return;
    _notice(AppLocalizations.of(context).userSavedNotice);
  }

  Future<void> _credentials(Member member) async {
    final saved = await PluggyCredentialsSheet.show(
      context,
      onSubmit: (credentials) async => (await _viewModel.updateCredentials(
        member.id,
        credentials,
      )).failureOrNull,
    );
    if (saved != true || !mounted) return;
    _notice(AppLocalizations.of(context).pluggySavedNotice);
  }

  Future<void> _password(Member member) async {
    final saved = await PasswordSheet.show(
      context,
      onSubmit: (password) async =>
          (await _viewModel.updatePassword(member.id, password)).failureOrNull,
    );
    if (saved != true || !mounted) return;
    _notice(AppLocalizations.of(context).userPasswordSavedNotice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initial = widget.member;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.userDetailTitle)),
      body: initial == null
          ? EmptyState(
              icon: Icons.person_outline,
              title: l10n.detailMissing,
              action: OutlinedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: Text(l10n.detailBack),
              ),
            )
          : ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                final member = _viewModel.memberById(initial.id) ?? initial;
                return _Content(
                  member: member,
                  onEdit: () => unawaited(_edit(member)),
                  onPassword: () => unawaited(_password(member)),
                  onCredentials: () => unawaited(_credentials(member)),
                );
              },
            ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.member,
    required this.onEdit,
    required this.onPassword,
    required this.onCredentials,
  });

  final Member member;
  final VoidCallback onEdit;
  final VoidCallback onPassword;
  final VoidCallback onCredentials;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String shown(String? value) => value ?? l10n.userNotInformed;
    final rows = [
      (l10n.userFieldFirstName, member.firstName),
      (l10n.userFieldLastName, shown(member.lastName)),
      (l10n.userFieldSurname, shown(member.surname)),
      (l10n.userFieldEmail, shown(member.email)),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                member.initial,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            EllipsisText(
              member.displayName,
              tapToShow: true,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            EllipsisText(
              member.fullName,
              tapToShow: true,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _InfoRow(label: rows[i].$1, value: rows[i].$2),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.userEditAction),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onPassword,
          icon: const Icon(Icons.lock_outline),
          label: Text(l10n.userPasswordAction),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onCredentials,
          icon: const Icon(Icons.key_outlined),
          label: Text(l10n.userPluggyAction),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: EllipsisText(
                value,
                tapToShow: true,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
