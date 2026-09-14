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
    this.vychoziUtvar,
    this.vychoziPoradac,
    this.vychoziZodpovida,
  });

  final RezimVzhledu vzhled;

  /// Kód útvaru, na který se seznam otevře. `null` = všechny.
  ///
  /// Kód, ne název - názvy útvarů se v Heliosu přepisují, kód drží.
  final String? vychoziUtvar;

  /// Číslo pořadače, na který se seznam otevře. `null` = všechny.
  final String? vychoziPoradac;

  /// Kdo za zakázky zodpovídá - seznam se otevře jen na jeho zakázkách.
  /// `null` = všichni.
  ///
  /// Jméno, ne kód: podle jména filtruje i lišta nad seznamem, kód osoby
  /// do aplikace nechodí. Jméno se v Heliosu mění výjimečně (sňatek) -
  /// pak se filtr prostě přestane uplatňovat a jde vybrat znovu.
  final String? vychoziZodpovida;

  bool get maVychoziFiltr =>
      vychoziUtvar != null ||
      vychoziPoradac != null ||
      vychoziZodpovida != null;

  Nastaveni copyWith({
    RezimVzhledu? vzhled,
    String? vychoziUtvar,
    bool zrusUtvar = false,
    String? vychoziPoradac,
    bool zrusPoradac = false,
    String? vychoziZodpovida,
    bool zrusZodpovida = false,
  }) {
    return Nastaveni(
      vzhled: vzhled ?? this.vzhled,
      vychoziUtvar: zrusUtvar ? null : (vychoziUtvar ?? this.vychoziUtvar),
      vychoziPoradac: zrusPoradac
          ? null
          : (vychoziPoradac ?? this.vychoziPoradac),
      vychoziZodpovida: zrusZodpovida
          ? null
          : (vychoziZodpovida ?? this.vychoziZodpovida),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Nastaveni &&
          other.vzhled == vzhled &&
          other.vychoziUtvar == vychoziUtvar &&
          other.vychoziPoradac == vychoziPoradac &&
          other.vychoziZodpovida == vychoziZodpovida);

  @override
  int get hashCode =>
      Object.hash(vzhled, vychoziUtvar, vychoziPoradac, vychoziZodpovida);
}
