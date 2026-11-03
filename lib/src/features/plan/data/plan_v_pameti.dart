import '../../orders/domain/entities/plan_klempirny.dart';

/// Typy úkonů bez serveru - ukázková data a testy. Na serveru je číselník
/// `plan_klempirny_typy`.
const typyUkonuVPameti = [
  TypUkonu(kod: 'demontaz', nazev: 'Demontáž', barva: '#A16207'),
  TypUkonu(kod: 'klempirna', nazev: 'Klempířské práce', barva: '#1D4ED8'),
  TypUkonu(kod: 'priprava_lak', nazev: 'Příprava na lak', barva: '#0E7490'),
  TypUkonu(kod: 'lakovna', nazev: 'Lakovna', barva: '#BE123C'),
  TypUkonu(kod: 'montaz', nazev: 'Montáž', barva: '#7C3AED'),
  TypUkonu(kod: 'kontrola', nazev: 'Kontrola', barva: '#15803D'),
];

TypUkonu _typ(String kod, PlanKlempirny? plan) => typyUkonuVPameti.firstWhere(
  (t) => t.kod == kod,
  // Vyřazený typ číselník nemá - starému úkonu ale zůstává.
  orElse: () => plan!.ukony.firstWhere((u) => u.typ.kod == kod).typ,
);

UkonPlanu _ukon(int id, VstupUkonu v, TypUkonu typ, String? zaplanoval) =>
    UkonPlanu(
      id: id,
      typ: typ,
      od: v.od,
      do_: v.do_,
      poznamka: v.poznamka,
      hotovo: v.hotovo,
      zaplanoval: zaplanoval,
    );

/// Plán (JSON jako ze serveru) po přidání úkonu.
Map<String, dynamic> pridejUkonVPameti(
  Map<String, dynamic>? json,
  VstupUkonu v, {
  required String autor,
}) {
  final plan = json == null ? null : PlanKlempirny.fromJson(json);
  final ukony = plan?.ukony ?? const <UkonPlanu>[];
  final id = ukony.fold(0, (max, u) => u.id > max ? u.id : max) + 1;
  return PlanKlempirny.zUkonu([
    ...ukony,
    _ukon(id, v, _typ(v.typKod, plan), autor),
  ], kodLaku: v.kodLaku).toJson();
}

/// Plán po úpravě úkonu [id].
Map<String, dynamic> upravUkonVPameti(
  Map<String, dynamic> json,
  int id,
  VstupUkonu v,
) {
  final plan = PlanKlempirny.fromJson(json);
  return PlanKlempirny.zUkonu([
    for (final u in plan.ukony)
      u.id == id ? _ukon(id, v, _typ(v.typKod, plan), u.zaplanoval) : u,
  ], kodLaku: v.kodLaku).toJson();
}

/// Plán po smazání úkonu [id]; `null`, když to byl poslední.
Map<String, dynamic>? smazUkonVPameti(Map<String, dynamic> json, int id) {
  final plan = PlanKlempirny.fromJson(json);
  final ukony = [
    for (final u in plan.ukony)
      if (u.id != id) u,
  ];
  return ukony.isEmpty
      ? null
      : PlanKlempirny.zUkonu(ukony, kodLaku: plan.kodLaku).toJson();
}
