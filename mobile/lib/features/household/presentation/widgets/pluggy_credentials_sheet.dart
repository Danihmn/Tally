import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/core/widgets/confirm_dialog.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/presentation/viewmodels/user_form.dart';
import 'package:mobile/features/household/presentation/widgets/user_fields.dart';
import 'package:mobile/features/household/presentation/widgets/user_sheet_frame.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Saves the credentials. Returns `null` when it worked, or why it did not
/// (the sheet then stays open and shows the failure).
typedef PluggyCredentialsSubmit = Future<Failure?> Function(
  PluggyCredentials credentials,
);

/// "Credenciais da Pluggy": only the Client ID and the Client Secret of a
/// person, in a sheet of their own. Before saving it asks the person to
/// confirm, because wrong credentials break the bank data of that person.
class PluggyCredentialsSheet extends StatefulWidget {
  const PluggyCredentialsSheet({super.key, required this.onSubmit});

  final PluggyCredentialsSubmit onSubmit;

  /// Shows the sheet. The result is `true` when the credentials were saved.
  static Future<bool?> show(
    BuildContext context, {
    required PluggyCredentialsSubmit onSubmit,
  }) => showAppBottomSheet<bool>(
    context,
    builder: (context) => PluggyCredentialsSheet(onSubmit: onSubmit),
  );

  @override
  State<PluggyCredentialsSheet> createState() => _PluggyCredentialsSheetState();
}

class _PluggyCredentialsSheetState extends State<PluggyCredentialsSheet> {
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();

  Map<UserFormField, UserFormError> _errors = const {};
  bool _submitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = validatePluggyCredentials(
      clientId: _clientId.text,
      clientSecret: _clientSecret.text,
    );
    if (!result.isValid) {
      setState(() => _errors = result.errors);
      return;
    }
    setState(() => _errors = const {});
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.pluggyConfirmTitle,
      message: l10n.pluggyConfirmMessage,
      confirmLabel: l10n.pluggyConfirmOk,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _failure = null;
      _submitting = true;
    });
    final failure = await widget.onSubmit(result.value!);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return UserSheetFrame(
      title: l10n.userPluggyAction,
      submitLabel: l10n.pluggySave,
      submitting: _submitting,
      failure: _failure,
      onSubmit: _submit,
      children: [
        const SizedBox(height: AppSpacing.xxs),
        Text(l10n.userPluggyIntro, style: muted),
        const SizedBox(height: AppSpacing.xxs),
        Text(l10n.userPluggyHidden, style: muted),
        PluggyCredentialFields(
          clientId: _clientId,
          clientSecret: _clientSecret,
          errors: _errors,
        ),
      ],
    );
  }
}
