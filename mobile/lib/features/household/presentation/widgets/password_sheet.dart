import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/household/presentation/viewmodels/user_form.dart';
import 'package:mobile/features/household/presentation/widgets/user_fields.dart';
import 'package:mobile/features/household/presentation/widgets/user_sheet_frame.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Saves the new password. Returns `null` when it worked, or why it did not
/// (the sheet then stays open and shows the failure).
typedef PasswordSubmit = Future<Failure?> Function(String password);

/// "Alterar senha": a new password for a person of the house.
class PasswordSheet extends StatefulWidget {
  const PasswordSheet({super.key, required this.onSubmit});

  final PasswordSubmit onSubmit;

  /// Shows the sheet. The result is `true` when the password was saved.
  static Future<bool?> show(
    BuildContext context, {
    required PasswordSubmit onSubmit,
  }) => showAppBottomSheet<bool>(
    context,
    builder: (context) => PasswordSheet(onSubmit: onSubmit),
  );

  @override
  State<PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<PasswordSheet> {
  final _password = TextEditingController();

  UserFormError? _error;
  bool _submitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = validatePassword(_password.text);
    setState(() => _error = result.errors[UserFormField.password]);
    if (!result.isValid) return;
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
    final error = _error;
    return UserSheetFrame(
      title: l10n.userPasswordAction,
      submitLabel: l10n.userPasswordSave,
      submitting: _submitting,
      failure: _failure,
      onSubmit: _submit,
      children: [
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.userPasswordIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FilterSectionLabel(l10n.userFieldPassword),
        SecretField(
          controller: _password,
          helperText: l10n.userFieldPasswordHelp,
          errorText: error == null ? null : userFormErrorText(l10n, error),
        ),
      ],
    );
  }
}
