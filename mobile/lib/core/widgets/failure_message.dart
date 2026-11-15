import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// pt-BR text for a [Failure]. The server's own text is never shown.
String failureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      UnauthorizedFailure() => l10n.failureUnauthorized,
      NotFoundFailure() => l10n.failureNotFound,
      ConflictFailure() => l10n.failureConflict,
      EmailAlreadyExistsFailure() => l10n.failureEmailExists,
      ValidationFailure() => l10n.failureValidation,
      NoRecurrencesFailure() => l10n.failureNoRecurrences,
      ConversationFullFailure() => l10n.failureConversationFull,
      ServerUnavailableFailure() => l10n.failureServer,
      NetworkFailure() => l10n.failureNetwork,
      TimeoutFailure() => l10n.failureTimeout,
      UnknownFailure() => l10n.failureUnknown,
    };

/// Shows a floating error notice (401, 404, 409, 422 and 503 only show this).
void showFailureSnackBar(BuildContext context, Failure failure) {
  final message = failureMessage(AppLocalizations.of(context), failure);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
