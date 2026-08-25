import 'package:flutter/widgets.dart';

/// Typografie: IBM Plex Sans pro UI text, IBM Plex Mono pro čísla zakázek,
/// SPZ, datumy a technické labely (rychlé skenování na dílně).
///
/// Fonty jsou bundlované v `assets/fonts/` - appka je čitelná i bez sítě.
abstract final class AppFonts {
  static const String sans = 'IBM Plex Sans';
  static const String mono = 'IBM Plex Mono';
}

/// Sémantické textové styly. Barvu doplňuje volající (podle palety).
abstract final class AppTextStyles {
  static const TextStyle loginTitle = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 33,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.825, // -0.025em
    height: 1.05,
  );

  static const TextStyle loginSubtitle = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Titul app baru - velikost se liší podle platformy (iOS 25 / Android 21).
  static TextStyle appBarTitle({required bool isIOS}) => TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: isIOS ? 25 : 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static const TextStyle appBarMeta = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
  );

  /// SPZ v detailu zakázky.
  static const TextStyle plateLarge = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 23,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.23,
  );

  /// SPZ chip v kartě seznamu.
  static const TextStyle plateChip = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Model vozidla v kartě.
  static const TextStyle cardModel = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  /// Hlavní datový text karty.
  static const TextStyle cardBody = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle meta = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle metaSmall = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Nadpis sekce - "POSTUP ZAKÁZKY", "POZNÁMKY A ÚKONY".
  static const TextStyle overline = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1, // .1em
  );

  /// Mono label - stavová řádka loginu, číslo zakázky v detailu.
  static const TextStyle monoLabel = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.26, // .12em
  );

  /// Číslo zakázky v kartě seznamu.
  static const TextStyle orderNumber = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
  );

  /// Datum v info boxu detailu.
  static const TextStyle dataValue = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle badge = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.11,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.155,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle noteText = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}
