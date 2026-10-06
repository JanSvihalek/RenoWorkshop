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

/// Záložka, na které se aplikace otevře po spuštění.
///
/// Kdo dělá hlavně příjem, nechce pokaždé začínat seznamem zakázek.
/// Nastavení mezi nabídkou není - po startu ho nikdo nepotřebuje.
enum UvodniZalozka {
  zakazky('Zakázky'),
  vozidlo('Vozidlo');

  const UvodniZalozka(this.label);

  final String label;

  static UvodniZalozka zNazvu(String? nazev) {
    // Příjem a Vozidla byly do 1.6 dvě záložky - kdo měl úvodní jednu
    // z nich, otevře se na Vozidle, které je nahradilo.
    if (nazev == 'prijem' || nazev == 'vozidla') return UvodniZalozka.vozidlo;
    for (final zalozka in values) {
      if (zalozka.name == nazev) return zalozka;
    }
    return UvodniZalozka.zakazky;
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
    this.vychoziZpracovatelId,
    this.vychoziZpracovatelJmeno,
    this.slozkaFotek,
    this.ukladatFotkyDoZarizeni = false,
    this.skenovatPoOtevreni = true,
    this.samoRozpoznatSpz = false,
    this.zobrazeniZakazek = ZobrazeniZakazek.karty,
    this.uvodniZalozka = UvodniZalozka.zakazky,
    this.ukazkovaData = false,
  });

  final RezimVzhledu vzhled;

  /// Kde je spoušť na obrazovce skeneru SPZ a VINu.
  final UmisteniSpouste spoust;

  /// Po klepnutí na záložku Vozidlo rovnou otevřít skener.
  /// Obojí vždycky začíná SPZ, takže je to o dvě klepnutí míň; kdo píše
  /// radši ručně, si to vypne.
  final bool skenovatPoOtevreni;

  /// Skener čte obraz průběžně a SPZ vyhledá sám, bez spouště - jakmile
  /// ji v rámečku přečte víckrát po sobě stejně. VIN se dál fotí spouští.
  ///
  /// Vypnuté ve výchozím stavu: průběžné čtení víc vybíjí baterii a na
  /// zařízeních zatím není vyzkoušené (6. 10. 2026).
  final bool samoRozpoznatSpz;

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

  /// Zpracovatel, na jehož zakázkách se seznam otevře. Id zaměstnance
  /// z Heliosu, `0` = zakázky bez zpracovatele, `null` = všichni.
  final int? vychoziZpracovatelId;

  /// Jméno k [vychoziZpracovatelId] - aby se volba dala ukázat, i když
  /// zrovna nemá žádnou zakázku a mezi načtenými není.
  final String? vychoziZpracovatelJmeno;

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

  /// Kam se aplikace otevře po spuštění a po přihlášení.
  final UvodniZalozka uvodniZalozka;

  /// Smyšlené zakázky místo Heliosu, i když build služba má. Mimo firemní
  /// síť se na server nedostane - takhle jde appku aspoň projít
  /// a ukázat. Nic z toho se do Heliosu ani na server nezapíše.
  final bool ukazkovaData;

  bool get maVychoziFiltr =>
      vychoziUtvar != null ||
      vychoziPoradac != null ||
      vychoziZodpovida != null ||
      vychoziZpracovatelId != null;

  Nastaveni copyWith({
    RezimVzhledu? vzhled,
    UmisteniSpouste? spoust,
    String? vychoziUtvar,
    bool zrusUtvar = false,
    String? vychoziPoradac,
    bool zrusPoradac = false,
    String? vychoziZodpovida,
    bool zrusZodpovida = false,
    int? vychoziZpracovatelId,
    String? vychoziZpracovatelJmeno,
    bool zrusZpracovatele = false,
    String? slozkaFotek,
    bool zrusSlozkuFotek = false,
    bool? ukladatFotkyDoZarizeni,
    bool? skenovatPoOtevreni,
    bool? samoRozpoznatSpz,
    ZobrazeniZakazek? zobrazeniZakazek,
    UvodniZalozka? uvodniZalozka,
    bool? ukazkovaData,
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
      vychoziZpracovatelId: zrusZpracovatele
          ? null
          : (vychoziZpracovatelId ?? this.vychoziZpracovatelId),
      vychoziZpracovatelJmeno: zrusZpracovatele
          ? null
          : (vychoziZpracovatelJmeno ?? this.vychoziZpracovatelJmeno),
      slozkaFotek: zrusSlozkuFotek ? null : (slozkaFotek ?? this.slozkaFotek),
      ukladatFotkyDoZarizeni:
          ukladatFotkyDoZarizeni ?? this.ukladatFotkyDoZarizeni,
      skenovatPoOtevreni: skenovatPoOtevreni ?? this.skenovatPoOtevreni,
      samoRozpoznatSpz: samoRozpoznatSpz ?? this.samoRozpoznatSpz,
      zobrazeniZakazek: zobrazeniZakazek ?? this.zobrazeniZakazek,
      uvodniZalozka: uvodniZalozka ?? this.uvodniZalozka,
      ukazkovaData: ukazkovaData ?? this.ukazkovaData,
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
          other.vychoziZpracovatelId == vychoziZpracovatelId &&
          other.vychoziZpracovatelJmeno == vychoziZpracovatelJmeno &&
          other.slozkaFotek == slozkaFotek &&
          other.ukladatFotkyDoZarizeni == ukladatFotkyDoZarizeni &&
          other.skenovatPoOtevreni == skenovatPoOtevreni &&
          other.samoRozpoznatSpz == samoRozpoznatSpz &&
          other.zobrazeniZakazek == zobrazeniZakazek &&
          other.uvodniZalozka == uvodniZalozka &&
          other.ukazkovaData == ukazkovaData);

  @override
  int get hashCode => Object.hash(
    vzhled,
    spoust,
    vychoziUtvar,
    vychoziPoradac,
    vychoziZodpovida,
    vychoziZpracovatelId,
    vychoziZpracovatelJmeno,
    slozkaFotek,
    ukladatFotkyDoZarizeni,
    skenovatPoOtevreni,
    samoRozpoznatSpz,
    zobrazeniZakazek,
    uvodniZalozka,
    ukazkovaData,
  );
}
