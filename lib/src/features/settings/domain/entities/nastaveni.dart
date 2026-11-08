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

/// Jak se ukazuje seznam zakázek.
///
/// Karty jsou na dílně v ruce čitelnější, tabulka ukáže víc zakázek naráz
/// a údaje pod sebou - u stolu se v ní hledá rychleji, podobně jako
/// v Heliosu.
enum ZobrazeniZakazek {
  karty('Karty'),
  tabulka('Tabulka');

  const ZobrazeniZakazek(this.label);

  final String label;

  static ZobrazeniZakazek zNazvu(String? nazev) {
    for (final zobrazeni in values) {
      if (zobrazeni.name == nazev) return zobrazeni;
    }
    return ZobrazeniZakazek.karty;
  }
}

/// Sloupce tabulky zakázek: pořadí klíčů a skryté klíče. Prázdné pořadí =
/// výchozí. Nese se s účtem, je stejné na webu i v aplikaci.
@immutable
class NastaveniSloupcu {
  const NastaveniSloupcu({this.poradi = const [], this.skryte = const []});

  /// Klíče sloupců (`prijato`, `spz`…) v pořadí, jak jdou zleva.
  final List<String> poradi;
  final List<String> skryte;

  bool get vychozi => poradi.isEmpty && skryte.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NastaveniSloupcu &&
          listEquals(other.poradi, poradi) &&
          listEquals(other.skryte, skryte));

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(poradi), Object.hashAll(skryte));
}

/// Co si aplikace pamatuje mezi spuštěními.
///
/// Drží se v telefonu. Výchozí filtr, sloupce tabulky, složka fotek
/// a úvodní záložka se navíc nesou s účtem (nastaveni_uctu.dart) - po
/// přihlášení je má člověk stejné i na webu a jiném telefonu. Vzhled,
/// karty/tabulka a skener zůstávají jen v telefonu: na sdíleném dílenském
/// telefonu by se jinak měnily pod rukama podle toho, kdo se zrovna přihlásil.
///
/// Ve výchozím filtru může být v každém výběru víc hodnot (jako na webu).
@immutable
class Nastaveni {
  const Nastaveni({
    this.vzhled = RezimVzhledu.podleSystemu,
    this.spoust = UmisteniSpouste.dole,
    this.vychoziPobocky = const [],
    this.vychoziUtvary = const [],
    this.vychoziPoradace = const [],
    this.vychoziZodpovedni = const [],
    this.vychoziZpracovatele = const [],
    this.jmenaZpracovatelu = const {},
    this.vychoziStavyHelios = const [],
    this.sloupce = const NastaveniSloupcu(),
    this.slozkaFotek,
    this.ukladatFotkyDoZarizeni = false,
    this.samoRozpoznatSpz = false,
    this.zobrazeniZakazek = ZobrazeniZakazek.karty,
    this.skrytUdaje = false,
    this.ukazkovaData = false,
  });

  final RezimVzhledu vzhled;

  /// Kde je spoušť na obrazovce skeneru SPZ a VINu.
  final UmisteniSpouste spoust;

  /// Skener čte obraz průběžně a SPZ vyhledá sám, bez spouště - jakmile
  /// ji v rámečku přečte víckrát po sobě stejně. VIN se dál fotí spouští.
  ///
  /// Vypnuté ve výchozím stavu: průběžné čtení víc vybíjí baterii.
  /// Vyzkoušené na iPadu (6. 10. 2026).
  final bool samoRozpoznatSpz;

  /// Kódy poboček, na které se seznam otevře. Prázdné = všechny. Nastavují
  /// se zatím jen na webu, appka je převezme z účtu.
  final List<String> vychoziPobocky;

  /// Kódy útvarů, na které se seznam otevře. Prázdné = všechny.
  ///
  /// Kód, ne název - názvy útvarů se v Heliosu přepisují, kód drží.
  final List<String> vychoziUtvary;

  /// Čísla pořadačů, na které se seznam otevře. Prázdné = všechny.
  final List<String> vychoziPoradace;

  /// Kdo za zakázky zodpovídá - seznam se otevře jen na jejich zakázkách.
  /// Prázdné = všichni.
  ///
  /// Jméno, ne kód: podle jména filtruje i lišta nad seznamem, kód osoby
  /// do aplikace nechodí. Jméno se v Heliosu mění výjimečně (sňatek) -
  /// pak se filtr prostě přestane uplatňovat a jde vybrat znovu.
  final List<String> vychoziZodpovedni;

  /// Zpracovatelé, na jejichž zakázkách se seznam otevře. Id zaměstnanců
  /// z Heliosu, `0` = zakázky bez zpracovatele, `-1` = já. Prázdné = všichni.
  final List<int> vychoziZpracovatele;

  /// Jména k [vychoziZpracovatele] - aby šla volba ukázat, i když člověk
  /// zrovna nemá žádnou zakázku a mezi načtenými není.
  final Map<int, String> jmenaZpracovatelu;

  /// Stavy z Heliosu („Zpracováváno"), na kterých se seznam otevře. Jako
  /// pobočky - nastavují se na webu, appka je převezme z účtu.
  final List<String> vychoziStavyHelios;

  /// Pořadí a viditelnost sloupců tabulky zakázek.
  final NastaveniSloupcu sloupce;

  /// Složka pobočky ve Foto-doc, kam jdou fotky z příjmu. `null` = podle
  /// pořadače zakázky.
  ///
  /// Pro pobočku, kde pořadač místo neurčuje - třeba když vůz přijímá jiná
  /// pobočka, než která zakázku založila.
  final String? slozkaFotek;

  /// Fotky z fotoaparátu se hned po vyfocení uloží i do galerie telefonu.
  ///
  /// Vypnuté ve výchozím stavu: fotky zákaznických vozů v galerii
  /// sdíleného telefonu nejsou samozřejmost a zabírají místo.
  final bool ukladatFotkyDoZarizeni;

  /// Karty, nebo řádková tabulka. V tabulce se detail otevírá přes celou
  /// obrazovku i na tabletu - vedle tabulky by se nevešel.
  final ZobrazeniZakazek zobrazeniZakazek;

  /// Pruh s údaji v hlavičce detailu je schovaný. Jen v zařízení.
  final bool skrytUdaje;

  /// Smyšlené zakázky místo Heliosu, i když build služba má. Mimo firemní
  /// síť se na server nedostane - takhle jde appku aspoň projít
  /// a ukázat. Nic z toho se do Heliosu ani na server nezapíše.
  final bool ukazkovaData;

  /// Kolik výběrů výchozího filtru je nastavených.
  int get pocetVychozichFiltru => [
    vychoziPobocky,
    vychoziStavyHelios,
    vychoziUtvary,
    vychoziPoradace,
    vychoziZodpovedni,
    vychoziZpracovatele,
  ].where((v) => v.isNotEmpty).length;

  bool get maVychoziFiltr => pocetVychozichFiltru > 0;

  /// Prázdný seznam výběr zruší.
  Nastaveni copyWith({
    RezimVzhledu? vzhled,
    UmisteniSpouste? spoust,
    List<String>? vychoziPobocky,
    List<String>? vychoziUtvary,
    List<String>? vychoziPoradace,
    List<String>? vychoziZodpovedni,
    List<int>? vychoziZpracovatele,
    Map<int, String>? jmenaZpracovatelu,
    List<String>? vychoziStavyHelios,
    NastaveniSloupcu? sloupce,
    String? slozkaFotek,
    bool zrusSlozkuFotek = false,
    bool? ukladatFotkyDoZarizeni,
    bool? samoRozpoznatSpz,
    ZobrazeniZakazek? zobrazeniZakazek,
    bool? skrytUdaje,
    bool? ukazkovaData,
  }) {
    return Nastaveni(
      vzhled: vzhled ?? this.vzhled,
      spoust: spoust ?? this.spoust,
      vychoziPobocky: vychoziPobocky ?? this.vychoziPobocky,
      vychoziUtvary: vychoziUtvary ?? this.vychoziUtvary,
      vychoziPoradace: vychoziPoradace ?? this.vychoziPoradace,
      vychoziZodpovedni: vychoziZodpovedni ?? this.vychoziZodpovedni,
      vychoziZpracovatele: vychoziZpracovatele ?? this.vychoziZpracovatele,
      jmenaZpracovatelu: jmenaZpracovatelu ?? this.jmenaZpracovatelu,
      vychoziStavyHelios: vychoziStavyHelios ?? this.vychoziStavyHelios,
      sloupce: sloupce ?? this.sloupce,
      slozkaFotek: zrusSlozkuFotek ? null : (slozkaFotek ?? this.slozkaFotek),
      ukladatFotkyDoZarizeni:
          ukladatFotkyDoZarizeni ?? this.ukladatFotkyDoZarizeni,
      samoRozpoznatSpz: samoRozpoznatSpz ?? this.samoRozpoznatSpz,
      zobrazeniZakazek: zobrazeniZakazek ?? this.zobrazeniZakazek,
      skrytUdaje: skrytUdaje ?? this.skrytUdaje,
      ukazkovaData: ukazkovaData ?? this.ukazkovaData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Nastaveni &&
          other.vzhled == vzhled &&
          other.spoust == spoust &&
          listEquals(other.vychoziPobocky, vychoziPobocky) &&
          listEquals(other.vychoziStavyHelios, vychoziStavyHelios) &&
          listEquals(other.vychoziUtvary, vychoziUtvary) &&
          listEquals(other.vychoziPoradace, vychoziPoradace) &&
          listEquals(other.vychoziZodpovedni, vychoziZodpovedni) &&
          listEquals(other.vychoziZpracovatele, vychoziZpracovatele) &&
          mapEquals(other.jmenaZpracovatelu, jmenaZpracovatelu) &&
          other.sloupce == sloupce &&
          other.slozkaFotek == slozkaFotek &&
          other.ukladatFotkyDoZarizeni == ukladatFotkyDoZarizeni &&
          other.samoRozpoznatSpz == samoRozpoznatSpz &&
          other.zobrazeniZakazek == zobrazeniZakazek &&
          other.skrytUdaje == skrytUdaje &&
          other.ukazkovaData == ukazkovaData);

  @override
  int get hashCode => Object.hashAll([
    vzhled,
    spoust,
    Object.hashAll(vychoziPobocky),
    Object.hashAll(vychoziStavyHelios),
    Object.hashAll(vychoziUtvary),
    Object.hashAll(vychoziPoradace),
    Object.hashAll(vychoziZodpovedni),
    Object.hashAll(vychoziZpracovatele),
    Object.hashAllUnordered(
      jmenaZpracovatelu.entries.map((e) => '${e.key}|${e.value}'),
    ),
    sloupce,
    slozkaFotek,
    ukladatFotkyDoZarizeni,
    samoRozpoznatSpz,
    zobrazeniZakazek,
    skrytUdaje,
    ukazkovaData,
  ]);
}
