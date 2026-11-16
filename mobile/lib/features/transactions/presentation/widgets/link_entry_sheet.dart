import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/presentation/widgets/entry_row.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The planned entries that can be linked, for a search text.
typedef EntryCandidates =
    Future<Result<List<FinancialEntry>>> Function(String search);

/// Links the entry. Returns `null` when it worked, or why it did not (the
/// sheet then stays open and shows the failure).
typedef EntryLinkSubmit = Future<Failure?> Function(FinancialEntry entry);

/// "Vincular lançamento": a search box and the planned entries of the same
/// type as the transaction. Tapping one links it and closes the sheet.
class LinkEntrySheet extends StatefulWidget {
  const LinkEntrySheet({
    super.key,
    required this.candidates,
    required this.onLink,
    this.today,
  });

  final EntryCandidates candidates;
  final EntryLinkSubmit onLink;

  /// The day used to mark overdue entries. Defaults to now.
  final DateTime? today;

  /// Shows the sheet. The result is `true` when an entry was linked.
  static Future<bool?> show(
    BuildContext context, {
    required EntryCandidates candidates,
    required EntryLinkSubmit onLink,
  }) => showAppBottomSheet<bool>(
    context,
    builder: (context) =>
        LinkEntrySheet(candidates: candidates, onLink: onLink),
  );

  @override
  State<LinkEntrySheet> createState() => _LinkEntrySheetState();
}

class _LinkEntrySheetState extends State<LinkEntrySheet> {
  final _search = TextEditingController();

  UiState<List<FinancialEntry>> _state = const UiLoading();
  bool _linking = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = const UiLoading());
    final result = await widget.candidates(_search.text.trim());
    if (!mounted) return;
    setState(() {
      _state = result.when<UiState<List<FinancialEntry>>>(
        success: (items) => items.isEmpty ? const UiEmpty() : UiSuccess(items),
        failure: UiError<List<FinancialEntry>>.new,
      );
    });
  }

  Future<void> _link(FinancialEntry entry) async {
    if (_linking) return;
    setState(() {
      _linking = true;
      _failure = null;
    });
    final failure = await widget.onLink(entry);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _linking = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final failure = _failure;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.linkEntryAction, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(l10n.linkEntryIntro, style: muted),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_load()),
              decoration: InputDecoration(
                hintText: l10n.linkEntrySearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  failureMessage(l10n, failure),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(child: _list(l10n, muted)),
          ],
        ),
      ),
    );
  }

  Widget _list(AppLocalizations l10n, TextStyle? muted) {
    switch (_state) {
      case UiInitial<List<FinancialEntry>>() ||
          UiLoading<List<FinancialEntry>>():
        return const Skeleton(height: 72);
      case UiError<List<FinancialEntry>>(:final failure):
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(failureMessage(l10n, failure), style: muted),
            TextButton(
              onPressed: () => unawaited(_load()),
              child: Text(l10n.retry),
            ),
          ],
        );
      case UiEmpty<List<FinancialEntry>>():
        return Text(l10n.linkEntryNone, style: muted);
      case UiSuccess<List<FinancialEntry>>(:final data):
        final today = widget.today ?? DateTime.now();
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: data.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => EntryRow(
              entry: data[i],
              today: today,
              onTap: () => unawaited(_link(data[i])),
            ),
          ),
        );
    }
  }
}
