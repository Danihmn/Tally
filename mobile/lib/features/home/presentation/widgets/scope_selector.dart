import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:mobile/features/home/presentation/widgets/member_palette.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Who appears": me, the other people, or the whole house. Up to three
/// choices fit in a segmented control. With more people the choices become
/// chips with the avatar of each person.
class ScopeSelector extends StatelessWidget {
  const ScopeSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<ScopeOption> options;
  final ScopeOption selected;
  final ValueChanged<ScopeOption> onSelected;

  String _label(AppLocalizations l10n, ScopeOption option) =>
      switch (option.kind) {
        ScopeKind.me => l10n.scopeMe,
        ScopeKind.house => l10n.scopeHouse,
        ScopeKind.member => option.member!.firstName,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (options.length <= 3) {
      return Semantics(
        label: l10n.scopeLabel,
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<ScopeOption>(
            showSelectedIcon: false,
            segments: [
              for (final option in options)
                ButtonSegment<ScopeOption>(
                  value: option,
                  label: Text(_label(l10n, option)),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (values) => onSelected(values.first),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                avatar: options[i].member == null
                    ? null
                    : CircleAvatar(
                        radius: 11,
                        backgroundColor: MemberPalette.colorFor(context, i),
                        child: Text(
                          options[i].member!.initial,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                label: Text(_label(l10n, options[i])),
                selected: options[i] == selected,
                onSelected: (_) => onSelected(options[i]),
              ),
            ),
        ],
      ),
    );
  }
}
