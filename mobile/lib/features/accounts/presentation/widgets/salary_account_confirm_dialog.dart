import 'package:material_ui/material_ui.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Asks before turning "conta salário" on or off: the change makes the server
/// reclassify every transfer of the household, so a tap by mistake should not
/// start it. Returns `true` only when the person confirms.
Future<bool> showSalaryAccountConfirmDialog(
  BuildContext context, {
  required AccountBalance account,
  required bool enabling,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final name = account.displayName;
      return AlertDialog(
        title: Text(
          enabling ? l10n.salaryConfirmOnTitle : l10n.salaryConfirmOffTitle,
        ),
        content: Text(
          enabling
              ? l10n.salaryConfirmOnText(name)
              : l10n.salaryConfirmOffText(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.salaryConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.salaryConfirmOk),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
