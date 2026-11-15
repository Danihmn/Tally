import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The two parts of the planning screen.
enum PlanningSection { entries, recurrences }

/// "Planejamento": the entries and the recurrences, one switch apart. When
/// the next month is provisioned it goes back to the entries, on that month.
///
/// The sections are built by the caller (the app with its DI container, tests
/// with fakes). [entriesBuilder] gets the month the list should open on, or
/// `null` for the usual one.
class PlanningView extends StatefulWidget {
  const PlanningView({
    super.key,
    required this.entriesBuilder,
    required this.recurrencesBuilder,
  });

  final Widget Function(DateTime? initialMonth) entriesBuilder;
  final Widget Function(ValueChanged<ProvisionResult> onProvisioned)
  recurrencesBuilder;

  @override
  State<PlanningView> createState() => _PlanningViewState();
}

class _PlanningViewState extends State<PlanningView> {
  PlanningSection _section = PlanningSection.entries;

  /// The recurrences load only the first time they are opened.
  bool _recurrencesOpened = false;

  /// Changes when the entries must be built again, on a new month.
  int _entriesGeneration = 0;
  DateTime? _entriesMonth;

  void _select(PlanningSection section) {
    setState(() {
      _section = section;
      if (section == PlanningSection.recurrences) _recurrencesOpened = true;
    });
  }

  void _onProvisioned(ProvisionResult result) {
    if (result.created == 0) return;
    setState(() {
      _entriesGeneration++;
      _entriesMonth = result.referenceMonth;
      _section = PlanningSection.entries;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.navEntries, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<PlanningSection>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: PlanningSection.entries,
                          label: Text(l10n.planningSectionEntries),
                        ),
                        ButtonSegment(
                          value: PlanningSection.recurrences,
                          label: Text(l10n.planningSectionRecurrences),
                        ),
                      ],
                      selected: {_section},
                      onSelectionChanged: (values) => _select(values.first),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _section.index,
                children: [
                  KeyedSubtree(
                    key: ValueKey(_entriesGeneration),
                    child: widget.entriesBuilder(_entriesMonth),
                  ),
                  if (_recurrencesOpened)
                    widget.recurrencesBuilder(_onProvisioned)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
