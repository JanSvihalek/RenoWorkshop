import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// Vzhled aplikace.
///
/// Volba je tu proto, že dílna a kancelář mají jiné světlo: v hale se
/// telefon čte líp ve tmavém, u pultu ve světlém. Systémové nastavení
/// zůstává výchozí, protože firemní telefony ho mají nastavené centrálně.
enum RezimVzhledu {
  podleSystemu('Podle systému', ThemeMode.system),
  svetly('Světlý', ThemeMode.light),
  tmavy('Tmavý', ThemeMode.dark);

  const RezimVzhledu(this.label, this.themeMode);

  final String label;
  final ThemeMode themeMode;

  static RezimVzhledu zNazvu(String? nazev) {
    for (final rezim in values) {
      if (rezim.name == nazev) return rezim;
    }
    return RezimVzhledu.podleSystemu;
  }
}

/// Co si aplikace pamatuje mezi spuštěními.
///
/// Drží se v telefonu, ne na serveru: jde o pohodlí konkrétního přístroje.
/// Na sdíleném dílenském telefonu by nastavení tažené z účtu znamenalo, že
/// se vzhled mění pod rukama podle toho, kdo se zrovna přihlásil.
@immutable
class Nastaveni {
  const Nastaveni({
    this.vzhled = RezimVzhledu.podleSystemu,
    this.vychoziPobocka,
    this.vychoziUtvar,
  });

  final RezimVzhledu vzhled;

  /// Kód pobočky, na kterou se seznam otevře. `null` = všechny.
  ///
  /// Kód, ne název - názvy útvarů se v Heliosu přepisují, kód drží.
  final String? vychoziPobocka;

  /// Kód útvaru v rámci pobočky. `null` = všechny.
  final String? vychoziUtvar;

  bool get maVychoziFiltr => vychoziPobocka != null || vychoziUtvar != null;

  Nastaveni copyWith({
    RezimVzhledu? vzhled,
    String? vychoziPobocka,
    String? vychoziUtvar,
    bool zrusPobocku = false,
    bool zrusUtvar = false,
  }) {
    return Nastaveni(
      vzhled: vzhled ?? this.vzhled,
      // Zrušení pobočky ruší i útvar - útvar bez pobočky nedává smysl.
      vychoziPobocka: zrusPobocku
          ? null
          : (vychoziPobocka ?? this.vychoziPobocka),
      vychoziUtvar: zrusPobocku || zrusUtvar
          ? null
          : (vychoziUtvar ?? this.vychoziUtvar),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Nastaveni &&
          other.vzhled == vzhled &&
          other.vychoziPobocka == vychoziPobocka &&
          other.vychoziUtvar == vychoziUtvar);

  @override
  int get hashCode => Object.hash(vzhled, vychoziPobocka, vychoziUtvar);
}
