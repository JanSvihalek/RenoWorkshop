import '../../../orders/domain/entities/kampan_vozidla.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../../../prijem/domain/entities/dezen.dart';

/// Vozidlo nalezené podle SPZ nebo VIN - řádek výsledků hledání.
class NalezeneVozidlo {
  const NalezeneVozidlo({
    required this.id,
    required this.spz,
    required this.vin,
    required this.model,
    required this.majitel,
    required this.pocetZakazek,
  });

  /// `cislo_subjektu` vozidla v Heliosu.
  final int id;
  final String spz;
  final String vin;
  final String model;
  final String? majitel;

  /// Kolik zakázek vůz u nás má, rozdělaných i ukončených. Pomáhá vybrat,
  /// když jedna SPZ vrátí víc vozidel (přeregistrace).
  final int pocetZakazek;
}

/// Karta vozidla: údaje vozu, dnešní majitel, kontaktní osoba a všechny
/// jeho zakázky napříč lety.
class KartaVozidla {
  const KartaVozidla({
    required this.id,
    required this.spz,
    required this.vin,
    required this.model,
    this.serie,
    this.palivo,
    this.motor,
    this.tachometr,
    this.prodano,
    this.kampanePodleStari = const [],
    this.dezen,
    this.dezenZmerenAt,
    this.majitel,
    this.kontakt,
    this.zakazky = const [],
  });

  final int id;
  final String spz;
  final String vin;
  final String model;
  final String? serie;
  final String? palivo;
  final String? motor;

  /// Stav tachometru z Heliosu, v kilometrech.
  final int? tachometr;

  /// Kdy RENOCAR vůz prodal - na dílně datum (první) registrace. Ne rok
  /// výroby, ten Helios nevede.
  final DateTime? prodano;

  /// Kampaně podle stáří od registrace (FitServis+), které se vozu týkají.
  final List<KampanVozidla> kampanePodleStari;

  /// Poslední dezén pneu změřený při příjmu; `null` = ještě se neměřil.
  final Dezen? dezen;
  final DateTime? dezenZmerenAt;

  /// Majitel **dnes**. Zákazník na staré zakázce může být jiný - vůz se
  /// mezitím prodal - a každá zakázka si ho nese sama.
  final MajitelVozidla? majitel;

  /// Komu se volá. U firemního vozu řidič, ne účtárna.
  final KontaktVozidla? kontakt;

  /// Rozdělané i ukončené, od nejnovější.
  final List<ServiceOrder> zakazky;
}

class MajitelVozidla {
  const MajitelVozidla({
    required this.nazev,
    this.cisloZakaznika,
    this.ico,
    this.dic,
    this.ulice,
    this.mesto,
    this.psc,
    this.telefon,
    this.email,
  });

  final String nazev;
  final String? cisloZakaznika;
  final String? ico;
  final String? dic;

  /// Ulice i s číslem, jak ji složí server (`Masarykova 123/4`).
  final String? ulice;
  final String? mesto;
  final String? psc;
  final String? telefon;
  final String? email;

  /// Adresa na jeden řádek, bez chybějících částí.
  String? get adresa {
    final obec = [psc, mesto].whereType<String>().join(' ');
    final casti = [ulice, if (obec.isNotEmpty) obec].whereType<String>();
    return casti.isEmpty ? null : casti.join(', ');
  }
}

class KontaktVozidla {
  const KontaktVozidla({required this.jmeno, this.telefon, this.email});

  final String jmeno;
  final String? telefon;
  final String? email;
}
