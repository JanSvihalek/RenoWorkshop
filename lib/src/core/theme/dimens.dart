/// Spacing, rádiusy a rozměry z design tokenů.
///
/// Sdílené napříč appkami rodiny Reno* - při zakládání další appky se tenhle
/// soubor kopíruje beze změny, mění se jen [AppColors].
abstract final class Insets {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double base = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double huge = 26;
  static const double giant = 44;
}

abstract final class Radii {
  static const double badge = 6;
  static const double chip = 9;
  static const double input = 11;
  static const double card = 14;
  static const double button = 12;

  /// iOS CTA.
  static const double ctaIos = 13;

  /// Android pill CTA.
  static const double ctaAndroid = 26;
}

abstract final class Sizes {
  /// Minimální doteková plocha (rukavice).
  static const double minTouchTarget = 44;
  static const double primaryButtonHeight = 56;
  static const double secondaryButtonHeight = 52;
  static const double ctaHeight = 52;
  static const double searchFieldHeight = 42;
  static const double timelineDot = 22;
}
