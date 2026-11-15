import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/theme/tally_colors.dart';

void main() {
  group('AppTheme', () {
    test('light_and_dark_use_the_design_tokens', () {
      final light = AppTheme.light(useGoogleFonts: false);
      final dark = AppTheme.dark(useGoogleFonts: false);

      expect(light.colorScheme.primary, const Color(0xFF34528F));
      expect(light.scaffoldBackgroundColor, const Color(0xFFF6F7F9));
      expect(light.extension<TallyColors>()!.income, const Color(0xFF17703F));
      expect(dark.colorScheme.primary, const Color(0xFF9EB6F0));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0E1116));
      expect(dark.extension<TallyColors>()!.expense, const Color(0xFFFF9784));
    });

    test('text_theme_follows_the_type_scale', () {
      final text = AppTheme.light(useGoogleFonts: false).textTheme;
      expect(text.headlineSmall!.fontSize, 24);
      expect(text.displaySmall!.fontSize, 36);
      expect(text.titleLarge!.fontSize, 20);
      expect(text.titleLarge!.fontWeight, FontWeight.w600);
      expect(text.bodyMedium!.fontSize, 14);
      expect(text.labelSmall!.fontSize, 11);
    });

    test('tally_colors_interpolate_between_themes', () {
      final mid = TallyColors.light.lerp(TallyColors.dark, 0.5);
      expect(mid.income, isNot(TallyColors.light.income));
      expect(TallyColors.light.lerp(null, 0.5), TallyColors.light);
    });
  });
}
