import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Typography of the design guide.
///
/// Space Grotesk for titles and big values, Inter for the rest. Money uses
/// tabular figures so digits line up in a column.
abstract final class AppTextTheme {
  static const _tabular = [FontFeature.tabularFigures()];

  /// [useGoogleFonts] is false in tests, so they never touch the network.
  static TextTheme build(Color color, {bool useGoogleFonts = true}) {
    TextStyle display(double size, double lineHeight) => _style(
      useGoogleFonts ? GoogleFonts.spaceGrotesk : null,
      size: size,
      lineHeight: lineHeight,
      weight: FontWeight.w600,
      color: color,
    );
    TextStyle body(double size, double lineHeight, FontWeight weight) => _style(
      useGoogleFonts ? GoogleFonts.inter : null,
      size: size,
      lineHeight: lineHeight,
      weight: weight,
      color: color,
    );

    return TextTheme(
      // "Valor em destaque": Space Grotesk 600 36/40.
      displaySmall: display(36, 40).copyWith(fontFeatures: _tabular),
      // "Título de tela": Space Grotesk 600 24/29.
      headlineSmall: display(24, 29),
      // "Título de seção": Inter 600 16/22.
      titleMedium: body(16, 22, FontWeight.w600),
      titleSmall: body(14, 20, FontWeight.w600),
      // "Corpo e linha principal": Inter 400 14/20.
      bodyMedium: body(14, 20, FontWeight.w400),
      bodyLarge: body(16, 24, FontWeight.w400),
      // "Legenda": Inter 400 12/16.
      bodySmall: body(12, 16, FontWeight.w400),
      labelLarge: body(14, 20, FontWeight.w600),
      labelMedium: body(12, 16, FontWeight.w600),
      // "Badge e rótulo": Inter 600 11/15.
      labelSmall: body(11, 15, FontWeight.w600),
    );
  }

  static TextStyle _style(
    TextStyle Function({
      TextStyle? textStyle,
      Color? color,
      double? fontSize,
      FontWeight? fontWeight,
      double? height,
    })?
    font, {
    required double size,
    required double lineHeight,
    required FontWeight weight,
    required Color color,
  }) {
    if (font == null) {
      return TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
      );
    }
    return font(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight / size,
    );
  }
}
