import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/features/household/presentation/viewmodels/user_form.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// pt-BR text for the reason a typed field was refused.
String userFormErrorText(AppLocalizations l10n, UserFormError error) =>
    switch (error) {
      UserFormError.required => l10n.formRequired,
      UserFormError.invalidEmail => l10n.userEmailInvalid,
      UserFormError.shortPassword => l10n.userPasswordShort,
      UserFormError.invalidClientId => l10n.pluggyClientIdInvalid,
    };

/// First name, last name, nickname and e-mail: the fields of a person that the
/// new and the edit forms share.
class UserNameFields extends StatelessWidget {
  const UserNameFields({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.surname,
    required this.email,
    required this.errors,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController surname;
  final TextEditingController email;
  final Map<UserFormField, UserFormError> errors;

  String? _error(AppLocalizations l10n, UserFormField field) {
    final error = errors[field];
    return error == null ? null : userFormErrorText(l10n, error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionLabel(l10n.userFieldFirstName),
        TextField(
          controller: firstName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          decoration: InputDecoration(
            errorText: _error(l10n, UserFormField.firstName),
          ),
        ),
        FilterSectionLabel(l10n.userFieldLastName),
        TextField(
          controller: lastName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          decoration: InputDecoration(helperText: l10n.formOptional),
        ),
        FilterSectionLabel(l10n.userFieldSurname),
        TextField(
          controller: surname,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          decoration: InputDecoration(
            helperText: '${l10n.formOptional}. ${l10n.userFieldSurnameHelp}',
            helperMaxLines: 2,
          ),
        ),
        FilterSectionLabel(l10n.userFieldEmail),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          decoration: InputDecoration(
            errorText: _error(l10n, UserFormField.email),
          ),
        ),
      ],
    );
  }
}

/// A text field for a secret (a password or the Pluggy client secret): the
/// text is hidden and never suggested or corrected.
class SecretField extends StatelessWidget {
  const SecretField({
    super.key,
    required this.controller,
    this.errorText,
    this.helperText,
  });

  final TextEditingController controller;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      inputFormatters: [LengthLimitingTextInputFormatter(300)],
      decoration: InputDecoration(errorText: errorText, helperText: helperText),
    );
  }
}

/// The Client ID and Client Secret of a Pluggy application.
class PluggyCredentialFields extends StatelessWidget {
  const PluggyCredentialFields({
    super.key,
    required this.clientId,
    required this.clientSecret,
    required this.errors,
  });

  final TextEditingController clientId;
  final TextEditingController clientSecret;
  final Map<UserFormField, UserFormError> errors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final idError = errors[UserFormField.clientId];
    final secretError = errors[UserFormField.clientSecret];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionLabel(l10n.pluggyClientId),
        TextField(
          controller: clientId,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [LengthLimitingTextInputFormatter(36)],
          decoration: InputDecoration(
            errorText: idError == null
                ? null
                : userFormErrorText(l10n, idError),
          ),
        ),
        FilterSectionLabel(l10n.pluggyClientSecret),
        SecretField(
          controller: clientSecret,
          errorText: secretError == null
              ? null
              : userFormErrorText(l10n, secretError),
        ),
      ],
    );
  }
}
