import 'package:flutter/material.dart';

/// Firemní paleta RenoWorkshop (BMW-inspirovaná, není oficiální BMW branding).
///
/// Hodnoty odpovídají design tokenům z návrhu. Barvy, které se liší mezi
/// světlým a tmavým režimem, žijí v [AppPalette] (ThemeExtension) - tahle
/// třída obsahuje jen konstanty nezávislé na režimu.
abstract final class AppColors {
  /// App bar, primární tlačítka, aktivní tab. Konstantní v obou režimech.
  static const Color primary = Color(0xFF031E49);

  /// Akcent - aktivní stav "V diagnostice", odkazy, avatar v hlavičce.
  static const Color accent = Color(0xFF4599FE);

  /// Blokované stavy ("Čeká na díly"), zpožděný termín.
  static const Color danger = Color(0xFFEE0405);

  /// Plochy karet ve světlém režimu.
  static const Color surfaceWhite = Color(0xFFFFFDFE);

  /// Primární text ve světlém režimu.
  static const Color ink = Color(0xFF2D4046);

  /// Hairline, neutrální plochy, dokončené kroky timeline.
  static const Color neutralLight = Color(0xFFB8CAD1);

  // Odvozené / doplňkové odstíny.
  static const Color loginGradientTop = Color(0xFF0A2A5C);
  static const Color loginGradientBottom = Color(0xFF02142F);
  static const Color repairBlue = Color(0xFF1668C9);
  static const Color qualityBlue = Color(0xFF0B3E7A);
  static const Color readyGreen = Color(0xFF1E7A5A);
  static const Color pickedUpGrey = Color(0xFF8FA3AC);
  static const Color mutedLight = Color(0xFF6B818A);
  static const Color muted2Light = Color(0xFF3D545C);
  static const Color plateLight = Color(0xFFE4EBEE);
  static const Color avatarLight = Color(0xFFD3DFE4);
  static const Color bgLight = Color(0xFFF2F5F7);
  static const Color bgDark = Color(0xFF04121F);
  static const Color cardDark = Color(0xFF10222E);

  // Microsoft brand (login SSO tlačítko).
  static const Color msRed = Color(0xFFF25022);
  static const Color msGreen = Color(0xFF7FBA00);
  static const Color msBlue = Color(0xFF00A4EF);
  static const Color msYellow = Color(0xFFFFB900);
}

/// Barvy závislé na režimu (light/dark). Čte se přes `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.text,
    required this.muted,
    required this.muted2,
    required this.hairline,
    required this.hairline2,
    required this.plate,
    required this.avatar,
    required this.cardShadow,
  });

  final Color background;
  final Color card;
  final Color text;
  final Color muted;
  final Color muted2;
  final Color hairline;
  final Color hairline2;

  /// Pozadí SPZ chipu.
  final Color plate;

  /// Pozadí avataru mechanika v seznamu.
  final Color avatar;

  /// Stín karty - v tmavém režimu prázdný seznam.
  final List<BoxShadow> cardShadow;

  static const AppPalette light = AppPalette(
    background: AppColors.bgLight,
    card: AppColors.surfaceWhite,
    text: AppColors.ink,
    muted: AppColors.mutedLight,
    muted2: AppColors.muted2Light,
    hairline: Color(0x172D4046), // rgba(45,64,70,.09)
    hairline2: Color(0x2E2D4046), // rgba(45,64,70,.18)
    plate: AppColors.plateLight,
    avatar: AppColors.avatarLight,
    cardShadow: [
      BoxShadow(
        color: Color(0x0D2D4046), // rgba(45,64,70,.05)
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
  );

  static const AppPalette dark = AppPalette(
    background: AppColors.bgDark,
    card: AppColors.cardDark,
    text: AppColors.surfaceWhite,
    muted: AppColors.pickedUpGrey,
    muted2: AppColors.neutralLight,
    hairline: Color(0x17FFFFFF), // rgba(255,255,255,.09)
    hairline2: Color(0x38FFFFFF), // rgba(255,255,255,.22)
    plate: Color(0x17FFFFFF),
    avatar: Color(0x1FFFFFFF), // rgba(255,255,255,.12)
    cardShadow: [],
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? text,
    Color? muted,
    Color? muted2,
    Color? hairline,
    Color? hairline2,
    Color? plate,
    Color? avatar,
    List<BoxShadow>? cardShadow,
  }) {
    return AppPalette(
      background: background ?? this.background,
      card: card ?? this.card,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      hairline: hairline ?? this.hairline,
      hairline2: hairline2 ?? this.hairline2,
      plate: plate ?? this.plate,
      avatar: avatar ?? this.avatar,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      muted2: Color.lerp(muted2, other.muted2, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairline2: Color.lerp(hairline2, other.hairline2, t)!,
      plate: Color.lerp(plate, other.plate, t)!,
      avatar: Color.lerp(avatar, other.avatar, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}
