import 'package:material_ui/material_ui.dart';

/// Color tokens of the design guide ("Tally · guia de componentes").

/// Page background behind the cards ("fundo").
const lightBackground = Color(0xFFF6F7F9);
const darkBackground = Color(0xFF0E1116);

const tallyLight = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF34528F),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDCE5F8),
  onPrimaryContainer: Color(0xFF1B2F5E),
  secondary: Color(0xFF434B59),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF14181F),
  onSurfaceVariant: Color(0xFF434B59),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF6F7F9),
  surfaceContainer: Color(0xFFEEF0F4),
  surfaceContainerHigh: Color(0xFFEEF0F4),
  surfaceContainerHighest: Color(0xFFEEF0F4),
  outline: Color(0xFFBFC6D2),
  outlineVariant: Color(0xFFE1E4EA),
  error: Color(0xFFB93A27),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFBE4DF),
  onErrorContainer: Color(0xFF42201A),
);

const tallyDark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9EB6F0),
  onPrimary: Color(0xFF10224B),
  primaryContainer: Color(0xFF27396A),
  onPrimaryContainer: Color(0xFFDCE5FB),
  secondary: Color(0xFFB5BCC9),
  onSecondary: Color(0xFF0E1116),
  surface: Color(0xFF171B22),
  onSurface: Color(0xFFEAEDF2),
  onSurfaceVariant: Color(0xFFB5BCC9),
  surfaceContainerLowest: Color(0xFF0E1116),
  surfaceContainerLow: Color(0xFF171B22),
  surfaceContainer: Color(0xFF1E232C),
  surfaceContainerHigh: Color(0xFF1E232C),
  surfaceContainerHighest: Color(0xFF1E232C),
  outline: Color(0xFF465061),
  outlineVariant: Color(0xFF2A303B),
  error: Color(0xFFFF9784),
  onError: Color(0xFF42201A),
  errorContainer: Color(0xFF42201A),
  onErrorContainer: Color(0xFFFFDAD3),
);
