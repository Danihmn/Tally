import 'package:material_ui/material_ui.dart';

/// One color for each person, chosen by the place of the person in the list of
/// the house, so the same person has the same color everywhere on the home.
abstract final class MemberPalette {
  static Color colorFor(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      const Color(0xFFD97757),
      const Color(0xFF6B7FD7),
    ];
    return colors[index % colors.length];
  }
}
