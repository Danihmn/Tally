import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/presentation/viewmodels/user_form.dart';
import 'package:mobile/features/household/presentation/widgets/user_fields.dart';
import 'package:mobile/features/household/presentation/widgets/user_sheet_frame.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Saves the changes. Returns `null` when it worked, or why it did not (the
/// sheet then stays open and shows the failure).
typedef UserEditSubmit = Future<Failure?> Function(UserChanges changes);

/// "Editar usuário": name, last name, nickname and e-mail of a person. The
/// Pluggy credentials have their own sheet.
class EditUserSheet extends StatefulWidget {
  const EditUserSheet({
    super.key,
    required this.member,
    required this.onSubmit,
  });

  final Member member;
  final UserEditSubmit onSubmit;

  /// Shows the sheet. The result is `true` when the person was saved.
  static Future<bool?> show(
    BuildContext context, {
    required Member member,
    required UserEditSubmit onSubmit,
  }) => showAppBottomSheet<bool>(
    context,
    builder: (context) => EditUserSheet(member: member, onSubmit: onSubmit),
  );

  @override
  State<EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<EditUserSheet> {
  late final _firstName = TextEditingController(text: widget.member.firstName);
  late final _lastName = TextEditingController(
    text: widget.member.lastName ?? '',
  );
  late final _surname = TextEditingController(
    text: widget.member.surname ?? '',
  );
  late final _email = TextEditingController(text: widget.member.email ?? '');

  Map<UserFormField, UserFormError> _errors = const {};
  bool _submitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _surname.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = validateUserEdit(
      firstName: _firstName.text,
      lastName: _lastName.text,
      surname: _surname.text,
      email: _email.text,
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
    return UserSheetFrame(
      title: l10n.userEditTitle,
      submitLabel: l10n.userSave,
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
      ],
    );
  }
}
