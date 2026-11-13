/// Spacing scale, corner radii and touch size of the design guide.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Side margin of every screen.
  static const double screenGutter = 16;
}

abstract final class AppRadius {
  /// Small button.
  static const double sm = 10;

  /// Field, notice.
  static const double md = 14;

  /// Card.
  static const double card = 20;

  /// Highlight card.
  static const double lg = 24;

  /// Button.
  static const double button = 26;
}

abstract final class AppSizes {
  /// Every touchable item is at least this high and wide.
  static const double minTouch = 44;

  static const double buttonHeight = 52;
}
