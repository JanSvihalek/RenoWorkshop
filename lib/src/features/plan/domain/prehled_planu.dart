import '../../orders/domain/entities/dilensky_stav.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/entities/service_order.dart';

/// Pobočka s klempírnou - v plánu se vybírá, čí týden se ukazuje.
class PobockaPlanu {
  const PobockaPlanu({required this.kod, required this.nazev});

  /// Druhá číslice útvaru (`1` = Brno).
  final String kod;
  final String nazev;

  @override
  bool operator ==(Object other) =>
      other is PobockaPlanu && other.kod == kod && other.nazev == nazev;

  @override
  int get hashCode => Object.hash(kod, nazev);
}

/// Řádek plánu: zakázka klempířského útvaru a její úkony na klempírně,
/// pokud už nějaké má.
class PolozkaPlanu {
  const PolozkaPlanu({
    required this.zakazkaId,
    required this.spz,
    required this.model,
    required this.zakaznik,
    this.pobockaKod,
    this.prijato,
    this.aktivni = true,
    this.plan,
    this.barva,
    this.zakazka,
  });

  final String zakazkaId;
  final String spz;
  final String model;
  final String zakaznik;
  final String? pobockaKod;

  /// Kdy vůz přijel - zakázky bez plánu jdou od nejstarší.
  final DateTime? prijato;

  /// Zakázka je v Heliosu ještě rozdělaná.
  final bool aktivni;

  /// `null` = zakázka zatím nemá plán.
  final PlanKlempirny? plan;

  /// Barva vozu z Heliosu - kód laku, když ho plán nemá.
  final BarvaVozu? barva;

  /// Kód laku: ručně zadaný v plánu, jinak z barvy vozu.
  String? get kodLaku => kodLakuZakazky(plan, barva);

  /// Celá zakázka jako v seznamu - filtruje se nad ní stejně a je z ní
  /// poslední dílenský stav (co se s vozem právě děje). Server ji v řádku
  /// plánu posílá celou; `null` jen u staršího API.
  final ServiceOrder? zakazka;

  factory PolozkaPlanu.fromJson(
    Map<String, dynamic> json, {
    ServiceOrder? zakazka,
  }) {
    final pobocka = json['branch'];
    final plan = json['plan'];
    return PolozkaPlanu(
      zakazkaId: json['orderId'] as String,
      spz: json['licensePlate'] as String? ?? '',
      model: json['model'] as String? ?? '',
      zakaznik: json['customerName'] as String? ?? '',
      pobockaKod: pobocka is Map<String, dynamic>
          ? pobocka['code'] as String?
          : null,
      prijato: DateTime.tryParse(json['receivedAt'] as String? ?? ''),
      aktivni: json['isActive'] as bool? ?? true,
      plan: plan is Map<String, dynamic> ? PlanKlempirny.fromJson(plan) : null,
      barva: BarvaVozu.zJson(json['vehicleColor']),
      zakazka: zakazka,
    );
  }
}

/// Plán na období: všechny rozdělané zakázky klempířských útvarů (s plánem
/// i bez), zakázky s blokem v období a pobočky klempíren.
class PrehledPlanu {
  const PrehledPlanu({required this.pobocky, required this.polozky});

  final List<PobockaPlanu> pobocky;
  final List<PolozkaPlanu> polozky;

  /// [zakazka] převede řádek na celou zakázku - umí to datová vrstva
  /// (DTO), doména ne.
  factory PrehledPlanu.fromJson(
    Map<String, dynamic> json, {
    ServiceOrder? Function(Map<String, dynamic> radek)? zakazka,
  }) => PrehledPlanu(
    pobocky: [
      for (final p in json['branches'] as List<dynamic>? ?? const [])
        PobockaPlanu(
          kod: (p as Map<String, dynamic>)['code'] as String,
          nazev: p['label'] as String? ?? '',
        ),
    ],
    polozky: [
      for (final p in json['entries'] as List<dynamic>? ?? const [])
        PolozkaPlanu.fromJson(
          p as Map<String, dynamic>,
          zakazka: zakazka?.call(p),
        ),
    ],
  );
}

/// Kód laku, který se v období opakuje - zakázky jde lakovat v jedné
/// várce.
class SpolecnyKod {
  const SpolecnyKod({required this.kod, required this.polozky});

  final String kod;
  final List<PolozkaPlanu> polozky;
}

/// Kódy laku, které mají v období aspoň dvě zakázky s úkonem na lakovně,
/// od nejčastějšího. Velikost písmen ani mezery okolo nehrají roli; zakázky
/// bez plánu nebo bez lakovny v období se nepočítají.
List<SpolecnyKod> spolecneKody(
  List<PolozkaPlanu> polozky,
  DateTime od,
  DateTime do_,
) {
  final podleKodu = <String, List<PolozkaPlanu>>{};
  for (final p in polozky) {
    final lakuje =
        p.plan?.ukony.any((u) => u.typ.jeLakovna && u.prekryva(od, do_)) ??
        false;
    if (!lakuje) continue;
    final kod = p.kodLaku;
    if (kod == null) continue;
    (podleKodu[kod] ??= []).add(p);
  }
  return [
    for (final MapEntry(:key, :value) in podleKodu.entries)
      if (value.length >= 2) SpolecnyKod(kod: key, polozky: value),
  ]..sort((a, b) => b.polozky.length.compareTo(a.polozky.length));
}

/// Pondělí týdne, do kterého den patří.
DateTime pondeli(DateTime den) {
  // Kalendářně, ne přes Duration - při změně času by se posunula hodina.
  return DateTime(den.year, den.month, den.day - (den.weekday - 1));
}

/// Pracovní dny (po-pá) od pondělí [zacatek] na [tydnu] týdnů.
List<DateTime> pracovniDny(DateTime zacatek, int tydnu) => [
  for (var t = 0; t < tydnu; t++)
    for (var d = 0; d < 5; d++)
      DateTime(zacatek.year, zacatek.month, zacatek.day + t * 7 + d),
];

/// Úkon na ose: které zobrazené dny zabírá a v které lince pod sebou jede.
class PruhUkonu {
  const PruhUkonu({
    required this.ukon,
    required this.prvni,
    required this.posledni,
    required this.linka,
  });

  final UkonPlanu ukon;

  /// Indexy do zobrazených dnů (víkendy v ose nejsou).
  final int prvni;
  final int posledni;
  final int linka;
}

/// Pruhy úkonů v zobrazených dnech: bez překryvu jedou v jedné lince, při
/// překryvu jde další o linku níž. Úkon jen přes víkend na ose není.
({List<PruhUkonu> pruhy, int linek}) pruhyVOse(
  List<UkonPlanu> ukony,
  List<DateTime> dny,
) {
  final viditelne = [
    for (final u in ukony)
      if (dny.indexWhere((d) => !d.isBefore(u.od)) case final prvni
          when prvni != -1)
        if (dny.lastIndexWhere((d) => !d.isAfter(u.do_)) case final posledni
            when posledni >= prvni)
          (ukon: u, prvni: prvni, posledni: posledni),
  ]..sort((a, b) => a.prvni.compareTo(b.prvni));
  final konce = <int>[];
  final pruhy = <PruhUkonu>[];
  for (final v in viditelne) {
    var linka = konce.indexWhere((konec) => konec < v.prvni);
    if (linka == -1) {
      linka = konce.length;
      konce.add(v.posledni);
    } else {
      konce[linka] = v.posledni;
    }
    pruhy.add(
      PruhUkonu(
        ukon: v.ukon,
        prvni: v.prvni,
        posledni: v.posledni,
        linka: linka,
      ),
    );
  }
  return (pruhy: pruhy, linek: konce.length);
}

/// Stav úkonu v průběhu opravy.
enum StavUkonu { hotovo, probiha, ceka }

/// Hotovo se značí ručně; probíhá ten, který odpovídá aktuálnímu dílenskému
/// stavu - typy úkonů mají stejné kódy jako stavy, stav mimo číselník se pozná
/// podle názvu. Jen se zobrazuje, nikam se neukládá: stavy se vracejí
/// i přeskakují a plán by se přepisoval špatně.
StavUkonu stavUkonu(UkonPlanu ukon, DilenskyStav? aktualni) {
  if (ukon.hotovo) return StavUkonu.hotovo;
  if (aktualni != null &&
      (aktualni.kod == ukon.typ.kod || aktualni.nazev == ukon.typ.nazev)) {
    return StavUkonu.probiha;
  }
  return StavUkonu.ceka;
}

/// Výchozí typ nového úkonu: po posledním naplánovaném jde další v pořadí
/// číselníku (Demontáž → Klempířské práce → ...), jinak první.
TypUkonu? vychoziTypUkonu(List<TypUkonu> typy, PlanKlempirny? plan) {
  if (typy.isEmpty) return null;
  final posledni = plan == null || plan.ukony.isEmpty
      ? null
      : plan.ukony.last.typ.kod;
  final i = typy.indexWhere((t) => t.kod == posledni);
  return i + 1 < typy.length ? typy[i + 1] : typy.first;
}

/// První pracovní den po konci plánu - kam nejspíš patří další úkon.
DateTime navazujiciDen(PlanKlempirny plan) {
  var d = DateTime(plan.do_.year, plan.do_.month, plan.do_.day + 1);
  while (d.weekday > 5) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return d;
}

/// Řádky plánu rozdělené pro osu: s blokem v období (od začátku bloku),
/// s plánem jindy a bez plánu (od nejdéle čekající).
({
  List<PolozkaPlanu> vObdobi,
  List<PolozkaPlanu> jindy,
  List<PolozkaPlanu> bezPlanu,
})
rozdelPolozky(List<PolozkaPlanu> polozky, DateTime od, DateTime do_) {
  final vObdobi = <PolozkaPlanu>[];
  final jindy = <PolozkaPlanu>[];
  final bezPlanu = <PolozkaPlanu>[];
  for (final p in polozky) {
    final plan = p.plan;
    if (plan == null) {
      bezPlanu.add(p);
    } else if (plan.prekryva(od, do_)) {
      vObdobi.add(p);
    } else {
      jindy.add(p);
    }
  }
  int podlePlanu(PolozkaPlanu a, PolozkaPlanu b) =>
      a.plan!.od.compareTo(b.plan!.od);
  final daleko = DateTime(9999);
  vObdobi.sort(podlePlanu);
  jindy.sort(podlePlanu);
  bezPlanu.sort((a, b) => (a.prijato ?? daleko).compareTo(b.prijato ?? daleko));
  return (vObdobi: vObdobi, jindy: jindy, bezPlanu: bezPlanu);
}

/// Filtr plánu nad rámec filtru zakázek: kód laku a stav plánu.
enum StavPlanuFiltr {
  naplanovano('Naplánováno'),
  hotovo('Hotovo'),
  bez('Bez plánu');

  const StavPlanuFiltr(this.label);

  final String label;

  bool sedi(PlanKlempirny? plan) => switch (this) {
    naplanovano => plan != null && !plan.hotovo,
    hotovo => plan != null && plan.hotovo,
    bez => plan == null,
  };
}
