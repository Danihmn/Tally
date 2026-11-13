import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Full-area error with a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offline = failure is NetworkFailure;
    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: failureMessage(l10n, failure),
      action: OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
    );
  }
}
