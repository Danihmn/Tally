import 'package:material_ui/material_ui.dart';

/// Colors that Material's `ColorScheme` has no slot for: income, expense and
/// warning (with their soft containers). Read it with `TallyColors.of(context)`.
@immutable
class TallyColors extends ThemeExtension<TallyColors> {
  const TallyColors({
    required this.income,
    required this.incomeContainer,
    required this.expense,
    required this.expenseContainer,
    required this.warning,
    required this.warningContainer,
  });

  static const light = TallyColors(
    income: Color(0xFF17703F),
    incomeContainer: Color(0xFFDDF3E6),
    expense: Color(0xFFB93A27),
    expenseContainer: Color(0xFFFBE4DF),
    warning: Color(0xFF80530A),
    warningContainer: Color(0xFFFFF0CC),
  );

  static const dark = TallyColors(
    income: Color(0xFF62D49C),
    incomeContainer: Color(0xFF143826),
    expense: Color(0xFFFF9784),
    expenseContainer: Color(0xFF42201A),
    warning: Color(0xFFF4C762),
    warningContainer: Color(0xFF3A2A0E),
  );

  final Color income;
  final Color incomeContainer;
  final Color expense;
  final Color expenseContainer;
  final Color warning;
  final Color warningContainer;

  static TallyColors of(BuildContext context) =>
      Theme.of(context).extension<TallyColors>()!;

  @override
  TallyColors copyWith({
    Color? income,
    Color? incomeContainer,
    Color? expense,
    Color? expenseContainer,
    Color? warning,
    Color? warningContainer,
  }) => TallyColors(
    income: income ?? this.income,
    incomeContainer: incomeContainer ?? this.incomeContainer,
    expense: expense ?? this.expense,
    expenseContainer: expenseContainer ?? this.expenseContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
  );

  @override
  TallyColors lerp(TallyColors? other, double t) {
    if (other == null) return this;
    return TallyColors(
      income: Color.lerp(income, other.income, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseContainer: Color.lerp(
        expenseContainer,
        other.expenseContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
    );
  }
}
