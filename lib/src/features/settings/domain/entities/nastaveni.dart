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

/// Kde je na obrazovce skeneru spoušť.
///
/// Na telefonu na výšku na dolní střed dosáhne palec kterékoli ruky. Na
/// tabletu drženém oběma rukama na šířku je ale dolní střed nejdál od
/// obou palců - tam je spoušť po straně blíž, a levák ji chce vlevo.
enum UmisteniSpouste {
  vlevo('Vlevo'),
  dole('Dole'),
  vpravo('Vpravo');

  const UmisteniSpouste(this.label);

  final String label;

  static UmisteniSpouste zNazvu(String? nazev) {
    for (final umisteni in values) {
      if (umisteni.name == nazev) return umisteni;
    }
    return UmisteniSpouste.dole;
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
    this.spoust = UmisteniSpouste.dole,
    this.vychoziUtvar,
    this.vychoziPoradac,
    this.vychoziZodpovida,
    this.slozkaFotek,
  });

  final RezimVzhledu vzhled;

  /// Kde je spoušť na obrazovce skeneru SPZ a VINu.
  final UmisteniSpouste spoust;

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

  /// Složka pobočky ve Foto-doc, kam jdou fotky z příjmu. `null` = podle
  /// pořadače zakázky.
  ///
  /// Pro pobočku, kde pořadač místo neurčuje - třeba když vůz přijímá jiná
  /// pobočka, než která zakázku založila.
  final String? slozkaFotek;

  bool get maVychoziFiltr =>
      vychoziUtvar != null ||
      vychoziPoradac != null ||
      vychoziZodpovida != null;

  Nastaveni copyWith({
    RezimVzhledu? vzhled,
    UmisteniSpouste? spoust,
    String? vychoziUtvar,
    bool zrusUtvar = false,
    String? vychoziPoradac,
    bool zrusPoradac = false,
    String? vychoziZodpovida,
    bool zrusZodpovida = false,
    String? slozkaFotek,
    bool zrusSlozkuFotek = false,
  }) {
    return Nastaveni(
      vzhled: vzhled ?? this.vzhled,
      spoust: spoust ?? this.spoust,
      vychoziUtvar: zrusUtvar ? null : (vychoziUtvar ?? this.vychoziUtvar),
      vychoziPoradac: zrusPoradac
          ? null
          : (vychoziPoradac ?? this.vychoziPoradac),
      vychoziZodpovida: zrusZodpovida
          ? null
          : (vychoziZodpovida ?? this.vychoziZodpovida),
      slozkaFotek: zrusSlozkuFotek ? null : (slozkaFotek ?? this.slozkaFotek),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Nastaveni &&
          other.vzhled == vzhled &&
          other.spoust == spoust &&
          other.vychoziUtvar == vychoziUtvar &&
          other.vychoziPoradac == vychoziPoradac &&
          other.vychoziZodpovida == vychoziZodpovida &&
          other.slozkaFotek == slozkaFotek);

  @override
  int get hashCode => Object.hash(
    vzhled,
    spoust,
    vychoziUtvar,
    vychoziPoradac,
    vychoziZodpovida,
    slozkaFotek,
  );
}
