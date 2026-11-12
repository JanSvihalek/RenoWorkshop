import 'dart:math' as math;

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

  /// Předpokládaný termín dokončení z Heliosu a jak blízko je.
  TerminDokonceni? terminDokonceni(DateTime dnes) =>
      TerminDokonceni.z(zakazka?.dueAt, dnes, aktivni: aktivni);

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

/// Kapacita dílny za jeden pracovní den.
class KapacitaDne {
  const KapacitaDne({required this.aw, this.lidi = 0, this.rucne = false});

  final int aw;

  /// Přítomných lidí v dílně.
  final int lidi;

  /// Ručně zadaný den, přebil počet lidí.
  final bool rucne;

  double get hodin => aw / awZaHodinu;
}

/// Plán na období: všechny rozdělané zakázky klempířských útvarů (s plánem
/// i bez), zakázky s blokem v období a pobočky klempíren.
class PrehledPlanu {
  const PrehledPlanu({
    required this.pobocky,
    required this.polozky,
    this.kapacity = const {},
  });

  final List<PobockaPlanu> pobocky;
  final List<PolozkaPlanu> polozky;

  /// Kapacita po pobočkách a pracovních dnech. Dílna, která v daný den
  /// chybí, kapacitu nemá.
  final Map<String, Map<DateTime, Map<Dilna, KapacitaDne>>> kapacity;

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
    kapacity: _kapacity(json['capacity']),
  );

  static Map<String, Map<DateTime, Map<Dilna, KapacitaDne>>> _kapacity(
    Object? data,
  ) {
    final vysledek = <String, Map<DateTime, Map<Dilna, KapacitaDne>>>{};
    for (final k in data as List<dynamic>? ?? const []) {
      final radek = k as Map<String, dynamic>;
      final dilna = Dilna.zKodu(radek['workshop'] as String?);
      final pobocka = radek['branch'] as String?;
      final den = DateTime.tryParse(radek['day'] as String? ?? '');
      final aw = (radek['aw'] as num?)?.toInt();
      if (dilna == null || pobocka == null || den == null || aw == null) {
        continue;
      }
      ((vysledek[pobocka] ??= {})[den] ??= {})[dilna] = KapacitaDne(
        aw: aw,
        lidi: (radek['people'] as num?)?.toInt() ?? 0,
        rucne: radek['manual'] == true,
      );
    }
    return vysledek;
  }
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

/// Všechny dny (po-ne) od pondělí [zacatek] na [tydnu] týdnů - sloupce osy.
List<DateTime> dnyOsy(DateTime zacatek, int tydnu) => [
  for (var i = 0; i < tydnu * 7; i++)
    DateTime(zacatek.year, zacatek.month, zacatek.day + i),
];

bool jeVikend(DateTime d) =>
    d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

/// Hodiny na jedno desetinné místo: `12`, `12,5`.
String hodinyText(double h) {
  final zaokrouhleno = (h * 10).round() / 10;
  return (zaokrouhleno == zaokrouhleno.roundToDouble()
          ? zaokrouhleno.toInt().toString()
          : zaokrouhleno.toString())
      .replaceAll('.', ',');
}

/// Vytížení dílen po dnech v hodinách. AW úkonu se dělí rovným dílem na jeho
/// pracovní dny; úkon bez AW nebo dílny se nepočítá. Volá se s řádky celé
/// pobočky, ne po filtru - vytížení dílny na filtru nezávisí.
Map<DateTime, Map<Dilna, double>> vytizeniDilen(List<PolozkaPlanu> polozky) {
  final vysledek = <DateTime, Map<Dilna, double>>{};
  for (final p in polozky) {
    for (final u in p.plan?.ukony ?? const <UkonPlanu>[]) {
      final aw = u.aw;
      final dilna = u.dilna;
      if (aw == null || aw <= 0 || dilna == null) continue;
      final dny = [
        for (var i = 0; i <= u.do_.difference(u.od).inDays; i++)
          if (DateTime(u.od.year, u.od.month, u.od.day + i) case final d
              when !jeVikend(d))
            d,
      ];
      for (final d in dny) {
        final den = vysledek[d] ??= {};
        den[dilna] = (den[dilna] ?? 0) + aw / awZaHodinu / dny.length;
      }
    }
  }
  return vysledek;
}

/// Pásmo vytížení: šedá pod 50 %, modrá do 84 %, oranžová do 100 %, červená
/// přes kapacitu. Jediné místo s hranicemi - používá je ukazatel, detail
/// i legenda.
enum UrovenVytizeni { nizke, ok, plno, pres }

UrovenVytizeni urovenVytizeni(int procent) {
  if (procent > 100) return UrovenVytizeni.pres;
  if (procent >= 85) return UrovenVytizeni.plno;
  return procent >= 50 ? UrovenVytizeni.ok : UrovenVytizeni.nizke;
}

/// Stav vytížení; [procent] `null` = kapacita chybí, nebo je nulová,
/// [uroven] `null` = šedá, není s čím porovnat. Kapacita 0 a nějaká práce je
/// přes kapacitu.
({int? procent, UrovenVytizeni? uroven}) stavVytizeni(
  double hodin,
  double? kapacita,
) {
  if (kapacita == null) return (procent: null, uroven: null);
  if (kapacita <= 0) {
    return (procent: null, uroven: hodin > 0 ? UrovenVytizeni.pres : null);
  }
  final procent = (hodin / kapacita * 100).round();
  return (procent: procent, uroven: urovenVytizeni(procent));
}

/// Vytížení dílny, nebo celého dne.
class RadekVytizeni {
  RadekVytizeni({required this.nazev, required this.hodin, this.kapacita}) {
    final stav = stavVytizeni(hodin, kapacita);
    procent = stav.procent;
    uroven = stav.uroven;
  }

  final String nazev;
  final double hodin;
  final double? kapacita;
  late final int? procent;
  late final UrovenVytizeni? uroven;

  /// `63 %`, bez kapacity `–`.
  String get procentText => procent == null ? '–' : '$procent %';

  /// `30/48 h`, bez kapacity jen `30 h`.
  String get hodinyZKapacity => switch (kapacita) {
    null => '${hodinyText(hodin)} h',
    final k => '${hodinyText(hodin)}/${hodinyText(k)} h',
  };
}

/// Vytížení jednoho dne po dílnách a celkem (součet hodin / součet kapacit).
({List<(Dilna, RadekVytizeni)> dilny, RadekVytizeni celkem}) vytizeniDne(
  Map<Dilna, double>? zatez,
  Map<Dilna, KapacitaDne>? kapacity,
) {
  final dilny = [
    for (final d in Dilna.values)
      (
        d,
        RadekVytizeni(
          nazev: d.nazev,
          hodin: zatez?[d] ?? 0,
          kapacita: kapacity?[d]?.hodin,
        ),
      ),
  ];
  final zadane = [for (final (_, r) in dilny) ?r.kapacita];
  return (
    dilny: dilny,
    celkem: RadekVytizeni(
      nazev: 'Celkem',
      hodin: dilny.fold(0.0, (soucet, d) => soucet + d.$2.hodin),
      kapacita: zadane.isEmpty
          ? null
          : zadane.fold<double>(0, (soucet, k) => soucet + k),
    ),
  );
}

/// Šířka zúženého víkendu ve 14 dnech.
const sirkaVikendu = 46.0;

/// Ve 14 dnech je víkend zúžený, v týdnu mají všechny dny stejnou šířku.
bool jeUzkyDen(DateTime d, List<DateTime> dny) => dny.length > 7 && jeVikend(d);

/// Šířky sloupců - stejné pro hlavičku, pozadí řádků i pruhy. Když se dny do
/// [dostupna] nevejdou, osa se posouvá do stran.
List<double> sirkySloupcu(List<DateTime> dny, double dostupna) {
  final uzke = dny.where((d) => jeUzkyDen(d, dny)).length;
  final den = math.max(
    dny.length > 7 ? 80.0 : 120.0,
    (dostupna - uzke * sirkaVikendu) / (dny.length - uzke),
  );
  return [for (final d in dny) jeUzkyDen(d, dny) ? sirkaVikendu : den];
}

enum StavPruhu { planovano, probiha, hotovo, poTerminu }

/// Barva pruhu: stejně jako osa v detailu, navíc prošlý plán je po termínu.
StavPruhu stavPruhu(PolozkaPlanu polozka, UkonPlanu ukon, DateTime dnes) {
  final osa = osaPrubehu(
    polozka.plan,
    polozka.zakazka?.historieStavu ?? const [],
  );
  final stav = osa.where((p) => p.ukon?.id == ukon.id).firstOrNull?.stav;
  if (ukon.hotovo || stav == StavPolozky.hotovo) return StavPruhu.hotovo;
  if (stav == StavPolozky.probiha) return StavPruhu.probiha;
  final dnesek = DateTime(dnes.year, dnes.month, dnes.day);
  return ukon.do_.isBefore(dnesek) ? StavPruhu.poTerminu : StavPruhu.planovano;
}

/// Úkon na ose: které zobrazené dny zabírá a v které lince pod sebou jede.
class PruhUkonu {
  const PruhUkonu({
    required this.ukon,
    required this.prvni,
    required this.posledni,
    required this.linka,
  });

  final UkonPlanu ukon;

  /// Indexy do zobrazených dnů.
  final int prvni;
  final int posledni;
  final int linka;
}

/// Pruhy úkonů v zobrazených dnech: bez překryvu jedou v jedné lince, při
/// překryvu jde další o linku níž.
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

/// Co s položkou osy průběhu je.
enum StavPolozky { probiha, hotovo, dalsi, ceka }

/// Řádek osy průběhu: úkon z plánu, nebo stav, který v plánu není.
class PolozkaOsy {
  PolozkaOsy({
    required this.nazev,
    required this.stav,
    required this.od,
    this.do_,
    this.mimoPlan = false,
    this.kdy,
    this.kdo,
    this.poznamka,
    this.ukon,
    this.zaznam,
  });

  final String nazev;
  StavPolozky stav;

  /// Stav u zakázky s plánem, který v plánu není.
  final bool mimoPlan;

  /// Kdy to začalo nebo má začít.
  final DateTime od;

  /// Kdy to skončilo nebo má skončit; `null` = probíhající stav bez plánu.
  final DateTime? do_;

  /// Dokončeno nebo zahájeno: kdy a kdo.
  final DateTime? kdy;
  final String? kdo;
  final String? poznamka;
  final UkonPlanu? ukon;
  final DilenskyStav? zaznam;
}

bool _patriKUkonu(DilenskyStav z, UkonPlanu u) =>
    z.kod == u.typ.kod || z.nazev == u.typ.nazev;

/// Plán a historie stavů v jedné ose. Typy úkonů mají stejné kódy jako stavy,
/// stav mimo číselník se pozná podle názvu. Co se ještě nedělá je nahoře, pak
/// co probíhá, pod tím co je hotové, vždy nejnovější první.
///
/// Krok končí tlačítkem Dokončit, jinak začátkem dalšího stavu. Jen se
/// zobrazuje: stavy se vracejí i přeskakují a plán by se přepisoval špatně.
List<PolozkaOsy> osaPrubehu(PlanKlempirny? plan, List<DilenskyStav> historie) {
  // Historie je od nejnovějšího: konec záznamu je začátek toho nad ním.
  ({DateTime? kdy, String? kdo}) konec(int i) {
    final z = historie[i];
    if (z.dokonceno != null) return (kdy: z.dokonceno, kdo: z.dokoncil);
    if (i == 0) return (kdy: null, kdo: null);
    return (kdy: historie[i - 1].zadano, kdo: historie[i - 1].autor);
  }

  final pouzite = <int>{};
  final polozky = <PolozkaOsy>[];

  for (final u in plan?.ukony ?? const <UkonPlanu>[]) {
    // Vrátili se k němu vícekrát: k úkonu patří poslední záznam.
    final i = historie.indexWhere((z) => _patriKUkonu(z, u));
    if (i >= 0) pouzite.add(i);
    final z = i >= 0 ? historie[i] : null;
    final konecZaznamu = i >= 0 ? konec(i) : null;
    final hotovo = konecZaznamu?.kdy != null || (z == null && u.hotovo);
    polozky.add(
      PolozkaOsy(
        nazev: u.typ.nazev,
        stav: z != null && !hotovo
            ? StavPolozky.probiha
            : hotovo
            ? StavPolozky.hotovo
            : StavPolozky.ceka,
        od: u.od,
        do_: u.do_,
        kdy: z != null ? konecZaznamu?.kdy ?? z.zadano : u.upraveno,
        kdo: z != null
            ? konecZaznamu?.kdy != null
                  ? konecZaznamu?.kdo
                  : z.autor
            : u.upravil,
        poznamka: switch ([
          if (u.poznamka.trim().isNotEmpty) u.poznamka.trim(),
          ?z?.poznamka,
        ].join(' · ')) {
          '' => null,
          final text => text,
        },
        ukon: u,
        zaznam: z,
      ),
    );
  }

  for (final (i, z) in historie.indexed) {
    if (pouzite.contains(i)) continue;
    final k = konec(i);
    // Opakovaný stav úkonu v plánu je, jen se k němu vrátili.
    final vPlanu = plan?.ukony.any((u) => _patriKUkonu(z, u)) ?? false;
    polozky.add(
      PolozkaOsy(
        nazev: z.nazev,
        stav: k.kdy != null ? StavPolozky.hotovo : StavPolozky.probiha,
        // Závada z Heliosu do plánu nepatří, ale není to práce navíc.
        mimoPlan:
            plan != null && !vPlanu && z.zavadaId == null && z.ukonId == null,
        od: z.zadano ?? DateTime(0),
        do_: k.kdy,
        kdy: k.kdy ?? z.zadano,
        kdo: k.kdy != null ? k.kdo : z.autor,
        poznamka: z.poznamka,
        zaznam: z,
      ),
    );
  }

  PolozkaOsy? dalsi;
  for (final p in polozky) {
    if (p.stav == StavPolozky.ceka &&
        (dalsi == null || p.od.isBefore(dalsi.od))) {
      dalsi = p;
    }
  }
  dalsi?.stav = StavPolozky.dalsi;

  int poradi(StavPolozky s) => switch (s) {
    StavPolozky.ceka || StavPolozky.dalsi => 0,
    StavPolozky.probiha => 1,
    StavPolozky.hotovo => 2,
  };
  polozky.sort((a, b) {
    final rozdil = poradi(a.stav) - poradi(b.stav);
    return rozdil != 0 ? rozdil : b.od.compareTo(a.od);
  });
  return polozky;
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

/// Kolik dní před termínem dokončení se řádek plánu zbarví oranžově.
const dnyPredTerminem = 3;

enum StavTerminu { vPoradku, blizi, poTerminu }

/// Předpokládaný termín dokončení zakázky v plánu: oranžově
/// [dnyPredTerminem] dny před termínem (i v den termínu), červeně až den
/// po něm. Kalendářní dny. Ukončená zakázka se nezvýrazňuje.
class TerminDokonceni {
  const TerminDokonceni({
    required this.termin,
    required this.stav,
    required this.zbyva,
  });

  final DateTime termin;
  final StavTerminu stav;

  /// Kolik dní do termínu zbývá; záporné = po termínu.
  final int zbyva;

  static TerminDokonceni? z(
    DateTime? termin,
    DateTime dnes, {
    bool aktivni = true,
  }) {
    if (termin == null) return null;
    // UTC kvůli změně času - den o hodinu kratší by se jinak nepočítal.
    final den = DateTime.utc(termin.year, termin.month, termin.day);
    final ted = DateTime.utc(dnes.year, dnes.month, dnes.day);
    final zbyva = den.difference(ted).inDays;
    final stav = !aktivni
        ? StavTerminu.vPoradku
        : zbyva < 0
        ? StavTerminu.poTerminu
        : zbyva <= dnyPredTerminem
        ? StavTerminu.blizi
        : StavTerminu.vPoradku;
    return TerminDokonceni(termin: termin, stav: stav, zbyva: zbyva);
  }
}
