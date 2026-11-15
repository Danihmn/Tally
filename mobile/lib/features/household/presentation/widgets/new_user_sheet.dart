import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';
import 'package:mobile/features/household/presentation/viewmodels/user_form.dart';
import 'package:mobile/features/household/presentation/widgets/user_fields.dart';
import 'package:mobile/features/household/presentation/widgets/user_sheet_frame.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Saves the new person. Returns `null` when it worked, or why it did not (the
/// sheet then stays open and shows the failure).
typedef UserCreateSubmit = Future<Failure?> Function(UserDraft draft);

/// "Novo usuário": a person for the house, with the credentials of their own
/// Pluggy application.
class NewUserSheet extends StatefulWidget {
  const NewUserSheet({super.key, required this.onSubmit});

  final UserCreateSubmit onSubmit;

  /// Shows the sheet. The result is `true` when the person was created.
  static Future<bool?> show(
    BuildContext context, {
    required UserCreateSubmit onSubmit,
  }) => showAppBottomSheet<bool>(
    context,
    builder: (context) => NewUserSheet(onSubmit: onSubmit),
  );

  @override
  State<NewUserSheet> createState() => _NewUserSheetState();
}

class _NewUserSheetState extends State<NewUserSheet> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _surname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();

  Map<UserFormField, UserFormError> _errors = const {};
  bool _submitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _surname.dispose();
    _email.dispose();
    _password.dispose();
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = validateNewUser(
      firstName: _firstName.text,
      lastName: _lastName.text,
      surname: _surname.text,
      email: _email.text,
      password: _password.text,
      clientId: _clientId.text,
      clientSecret: _clientSecret.text,
    );
    if (!result.isValid) {
      setState(() => _errors = result.errors);
      return;
    }
    setState(() {
      _errors = const {};
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
    final passwordError = _errors[UserFormField.password];
    return UserSheetFrame(
      title: l10n.userNewTitle,
      submitLabel: l10n.userCreate,
      submitting: _submitting,
      failure: _failure,
      onSubmit: _submit,
      children: [
        UserNameFields(
          firstName: _firstName,
          lastName: _lastName,
          surname: _surname,
          email: _email,
          errors: _errors,
        ),
        FilterSectionLabel(l10n.userFieldPassword),
        SecretField(
          controller: _password,
          helperText: l10n.userFieldPasswordHelp,
          errorText: passwordError == null
              ? null
              : userFormErrorText(l10n, passwordError),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.userPluggySection, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.userPluggyIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        PluggyCredentialFields(
          clientId: _clientId,
          clientSecret: _clientSecret,
          errors: _errors,
        ),
      ],
    );
  }
}
