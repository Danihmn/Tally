import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Temporary screen body for a tab whose feature is built in a later phase.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.construction_outlined,
        title: l10n.comingSoon,
        message: l10n.comingSoonMessage,
      ),
    );
  }
}
