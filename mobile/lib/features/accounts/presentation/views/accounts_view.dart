import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/widgets/coming_soon_view.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Placeholder until this feature is built.
class AccountsView extends StatelessWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) =>
      ComingSoonView(title: AppLocalizations.of(context).navAccounts);
}
