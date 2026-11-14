import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/utils/date_mask_formatter.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Title of a block of a filter sheet.
class FilterSectionLabel extends StatelessWidget {
  const FilterSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A date typed as dd/mm/aaaa, with its mask.
class FilterDateField extends StatelessWidget {
  const FilterDateField({
    super.key,
    required this.controller,
    required this.label,
    required this.error,
  });

  final TextEditingController controller;
  final String label;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [DateMaskFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: AppLocalizations.of(context).filterDateHint,
        errorText: error,
        errorMaxLines: 2,
      ),
    );
  }
}

/// An amount typed like 10,50.
class FilterAmountField extends StatelessWidget {
  const FilterAmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.error,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: 'R\$ ',
        errorText: error,
        errorMaxLines: 2,
      ),
    );
  }
}
