import 'package:flutter/foundation.dart';

/// Kde je příjem vozidla u zakázky.
enum StavPrijmu {
  nezahajen('not_started'),
  rozpracovany('in_progress'),
  dokoncen('completed');

  const StavPrijmu(this.klic);

  final String klic;

  static StavPrijmu zKlice(String? klic) => values.firstWhere(
    (stav) => stav.klic == klic,
    orElse: () => StavPrijmu.nezahajen,
  );
}

/// `kontrola` se zaškrtává, `datum` se zapisuje (platnost STK).
enum TypKontroly { kontrola, datum }

/// Jeden bod checklistu příjmu.
@immutable
class PolozkaPrijmu {
  const PolozkaPrijmu({
    required this.kod,
    required this.nazev,
    this.typ = TypKontroly.kontrola,
    this.povinna = true,
    this.splneno = false,
    this.hodnota,
    this.poznamka,
    this.zmenilKdo,
    this.zmenenoAt,
  });

  final String kod;
  final String nazev;
  final TypKontroly typ;

  /// Aktivní kontrola - bez ní příjem nejde dokončit. Nepovinná je jen
  /// kontrola, kterou mezitím vyřadili z checklistu.
  final bool povinna;
  final bool splneno;

  /// U typu [TypKontroly.datum] datum ve tvaru RRRR-MM-DD.
  final String? hodnota;

  /// Co technik při kontrole našel.
  final String? poznamka;
  final String? zmenilKdo;
  final DateTime? zmenenoAt;

  DateTime? get datum => hodnota == null ? null : DateTime.tryParse(hodnota!);

  bool get jeVyplnena => typ == TypKontroly.datum ? datum != null : splneno;

  PolozkaPrijmu copyWith({
    bool? splneno,
    String? hodnota,
    bool smazatHodnotu = false,
    String? poznamka,
    bool smazatPoznamku = false,
  }) => PolozkaPrijmu(
    kod: kod,
    nazev: nazev,
    typ: typ,
    povinna: povinna,
    splneno: splneno ?? this.splneno,
    hodnota: smazatHodnotu ? null : (hodnota ?? this.hodnota),
    poznamka: smazatPoznamku ? null : (poznamka ?? this.poznamka),
    zmenilKdo: zmenilKdo,
    zmenenoAt: zmenenoAt,
  );

  factory PolozkaPrijmu.fromJson(Map<String, dynamic> json) => PolozkaPrijmu(
    kod: json['code'] as String,
    nazev: json['label'] as String? ?? json['code'] as String,
    typ: json['type'] == 'date' ? TypKontroly.datum : TypKontroly.kontrola,
    povinna: json['required'] as bool? ?? true,
    splneno: json['checked'] as bool? ?? false,
    hodnota: json['value'] as String?,
    poznamka: json['note'] as String?,
    zmenilKdo: json['changedBy'] as String?,
    zmenenoAt: DateTime.tryParse(json['changedAt'] as String? ?? ''),
  );
}

/// Příjem vozidla k zakázce - checklist kontrol a kdo ho kdy dokončil.
@immutable
class Prijem {
  const Prijem({
    this.stav = StavPrijmu.nezahajen,
    this.polozky = const [],
    this.zahajilKdo,
    this.zahajenoAt,
    this.dokoncilKdo,
    this.dokoncenoAt,
  });

  final StavPrijmu stav;
  final List<PolozkaPrijmu> polozky;
  final String? zahajilKdo;
  final DateTime? zahajenoAt;
  final String? dokoncilKdo;
  final DateTime? dokoncenoAt;

  bool get jeDokoncen => stav == StavPrijmu.dokoncen;

  int get pocetPovinnych => polozky.where((p) => p.povinna).length;

  int get pocetVyplnenych =>
      polozky.where((p) => p.povinna && p.jeVyplnena).length;

  /// Počítá se v aplikaci, ne přebírá ze serveru: po zaškrtnutí se musí
  /// změnit hned, ne až po odpovědi.
  int get chybi => pocetPovinnych - pocetVyplnenych;

  int get pocetPoznamek =>
      polozky.where((p) => (p.poznamka ?? '').isNotEmpty).length;

  Prijem sPolozkou(PolozkaPrijmu polozka) => Prijem(
    stav: stav == StavPrijmu.nezahajen ? StavPrijmu.rozpracovany : stav,
    polozky: [
      for (final p in polozky)
        if (p.kod == polozka.kod) polozka else p,
    ],
    zahajilKdo: zahajilKdo,
    zahajenoAt: zahajenoAt,
    dokoncilKdo: dokoncilKdo,
    dokoncenoAt: dokoncenoAt,
  );

  factory Prijem.fromJson(Map<String, dynamic> json) => Prijem(
    stav: StavPrijmu.zKlice(json['status'] as String?),
    polozky: [
      for (final polozka in json['items'] as List? ?? const [])
        PolozkaPrijmu.fromJson(polozka as Map<String, dynamic>),
    ],
    zahajilKdo: json['startedBy'] as String?,
    zahajenoAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
    dokoncilKdo: json['completedBy'] as String?,
    dokoncenoAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
  );
}

/// Změna jedné položky - posílá se jen to, co se mění.
@immutable
class ZmenaPolozky {
  const ZmenaPolozky._(this.json);

  factory ZmenaPolozky.splneno(bool splneno) =>
      ZmenaPolozky._({'checked': splneno});

  /// Datum STK; `null` ho smaže.
  factory ZmenaPolozky.datum(DateTime? datum) =>
      ZmenaPolozky._({'value': datum == null ? null : datumProApi(datum)});

  /// Prázdná poznámka se smaže.
  factory ZmenaPolozky.poznamka(String? poznamka) => ZmenaPolozky._({
    'note': (poznamka ?? '').trim().isEmpty ? null : poznamka!.trim(),
  });

  final Map<String, Object?> json;

  PolozkaPrijmu pouzij(PolozkaPrijmu polozka) {
    var nova = polozka;
    if (json.containsKey('checked')) {
      nova = nova.copyWith(splneno: json['checked']! as bool);
    }
    if (json.containsKey('value')) {
      final hodnota = json['value'] as String?;
      nova = nova.copyWith(hodnota: hodnota, smazatHodnotu: hodnota == null);
    }
    if (json.containsKey('note')) {
      final poznamka = json['note'] as String?;
      nova = nova.copyWith(
        poznamka: poznamka,
        smazatPoznamku: poznamka == null,
      );
    }
    return nova;
  }
}

/// RRRR-MM-DD bez času a zóny - datum STK je den, ne okamžik.
String datumProApi(DateTime datum) =>
    '${datum.year.toString().padLeft(4, '0')}'
    '-${datum.month.toString().padLeft(2, '0')}'
    '-${datum.day.toString().padLeft(2, '0')}';
