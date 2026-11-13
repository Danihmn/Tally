import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/core/widgets/error_state.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Renders a [UiState]: skeleton while loading, a message when empty, an error
/// with retry on failure, and [builder] on success. Every list screen uses it,
/// so all of them behave the same.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.builder,
    this.loading,
    this.emptyTitle,
    this.emptyMessage,
  });

  final UiState<T> state;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  /// Replaces the default skeleton list.
  final Widget? loading;
  final String? emptyTitle;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      UiInitial<T>() || UiLoading<T>() => loading ?? const SkeletonList(),
      UiSuccess<T>(:final data) => builder(context, data),
      UiEmpty<T>() => EmptyState(
        title: emptyTitle ?? l10n.emptyTitle,
        message: emptyMessage ?? l10n.emptyMessage,
      ),
      UiError<T>(:final failure) => ErrorState(
        failure: failure,
        onRetry: onRetry,
      ),
    };
  }
}
