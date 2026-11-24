import 'package:flutter/material.dart';

/// Barvy změněné zakázky - proužek, tečka, kroužek kolem stavu dílna,
/// lišta a tooltip. Jediný zdroj pravdy; stejné hodnoty jako na webu
/// (`--zmena-*` v web/src/styly/zaklad.css). Čte se přes
/// `context.barvyZmen`.
///
/// [akcent] má na bílé kontrast jen 3,6 : 1 - na text je [text].
/// Modrá varianta, kdyby se oranžová neosvědčila: akcent #2563EB,
/// pozadí #EEF4FF, text #1D4ED8, okraj #C9D3E6.
@immutable
class BarvyZmen extends ThemeExtension<BarvyZmen> {
  const BarvyZmen({
    required this.akcent,
    required this.pozadiRadku,
    required this.text,
    required this.okraj,
    required this.tooltip,
    required this.tooltipText,
    required this.tooltipTlumene,
  });

  /// Tečka, proužek a kroužek. Ne na text.
  final Color akcent;

  /// Teplé pozadí změněného řádku a karty.
  final Color pozadiRadku;

  /// Text v oranžové (tlačítko „Zobrazit jen změněné").
  final Color text;

  /// Rámeček tlačítka a lišty.
  final Color okraj;

  /// Tmavé pozadí tooltipu a jeho texty.
  final Color tooltip;
  final Color tooltipText;
  final Color tooltipTlumene;

  static const BarvyZmen svetle = BarvyZmen(
    akcent: Color(0xFFEA580C),
    pozadiRadku: Color(0xFFFFF7ED),
    text: Color(0xFFC2410C),
    okraj: Color(0xFFFED7AA),
    tooltip: Color(0xFF111827),
    tooltipText: Colors.white,
    tooltipTlumene: Color(0xFF9CA3AF),
  );

  static const BarvyZmen tmave = BarvyZmen(
    akcent: Color(0xFFFB923C),
    pozadiRadku: Color(0x1AEA580C), // rgba(234, 88, 12, 0.10)
    text: Color(0xFFFDBA74),
    okraj: Color(0x59FB923C), // rgba(251, 146, 60, 0.35)
    tooltip: Color(0xFF1F2937),
    tooltipText: Colors.white,
    tooltipTlumene: Color(0xFF9CA3AF),
  );

  @override
  BarvyZmen copyWith({
    Color? akcent,
    Color? pozadiRadku,
    Color? text,
    Color? okraj,
    Color? tooltip,
    Color? tooltipText,
    Color? tooltipTlumene,
  }) => BarvyZmen(
    akcent: akcent ?? this.akcent,
    pozadiRadku: pozadiRadku ?? this.pozadiRadku,
    text: text ?? this.text,
    okraj: okraj ?? this.okraj,
    tooltip: tooltip ?? this.tooltip,
    tooltipText: tooltipText ?? this.tooltipText,
    tooltipTlumene: tooltipTlumene ?? this.tooltipTlumene,
  );

  @override
  BarvyZmen lerp(ThemeExtension<BarvyZmen>? other, double t) {
    if (other is! BarvyZmen) return this;
    return BarvyZmen(
      akcent: Color.lerp(akcent, other.akcent, t)!,
      pozadiRadku: Color.lerp(pozadiRadku, other.pozadiRadku, t)!,
      text: Color.lerp(text, other.text, t)!,
      okraj: Color.lerp(okraj, other.okraj, t)!,
      tooltip: Color.lerp(tooltip, other.tooltip, t)!,
      tooltipText: Color.lerp(tooltipText, other.tooltipText, t)!,
      tooltipTlumene: Color.lerp(tooltipTlumene, other.tooltipTlumene, t)!,
    );
  }
}

extension BarvyZmenContext on BuildContext {
  /// Barvy změněné zakázky; bez našeho theme (testy) podle jasu.
  BarvyZmen get barvyZmen =>
      Theme.of(this).extension<BarvyZmen>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? BarvyZmen.tmave
          : BarvyZmen.svetle);
}
