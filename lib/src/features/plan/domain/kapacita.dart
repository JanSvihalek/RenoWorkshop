import '../../orders/domain/entities/plan_klempirny.dart';
import 'prehled_planu.dart';

/// Kapacita dílen - kdo kam patří, kdy chybí a ručně zadané dny. Stejná
/// pravidla jako služba (`domain/kapacita-planu.ts`), jen s právem Kapacita.

/// Zařazení mimo dílny: člověk se do kapacity nepočítá.
const zarazeniMimo = 'mimo';

/// 7,5 hodiny práce.
const awClovekDen = 90;

class NepritomnostCloveka {
  const NepritomnostCloveka({
    required this.id,
    required this.od,
    required this.do_,
  });

  final int id;
  final DateTime od;
  final DateTime do_;

  factory NepritomnostCloveka.fromJson(Map<String, dynamic> json) =>
      NepritomnostCloveka(
        id: json['id'] as int,
        od: DateTime.parse(json['from'] as String),
        do_: DateTime.parse(json['to'] as String),
      );
}

/// Člověk s dílenským tarifem na klempířském středisku.
class ClovekKapacity {
  const ClovekKapacity({
    required this.id,
    this.jmeno,
    this.tarify = const [],
    this.dilnaPodleTarifu,
    this.prirazeno,
    this.nepritomnosti = const [],
  });

  final int id;
  final String? jmeno;
  final List<String> tarify;

  /// Kam patří podle tarifu z Heliosu.
  final Dilna? dilnaPodleTarifu;

  /// Ruční zařazení: kód dílny, nebo [zarazeniMimo]. `null` = podle tarifu.
  final String? prirazeno;
  final List<NepritomnostCloveka> nepritomnosti;

  /// Kde se opravdu počítá; `null` = nikde.
  Dilna? get dilna {
    if (prirazeno == zarazeniMimo) return null;
    return Dilna.zKodu(prirazeno) ?? dilnaPodleTarifu;
  }

  String get popisek => jmeno ?? 'Zaměstnanec $id';

  ClovekKapacity copyWith({
    String? Function()? prirazeno,
    List<NepritomnostCloveka>? nepritomnosti,
  }) => ClovekKapacity(
    id: id,
    jmeno: jmeno,
    tarify: tarify,
    dilnaPodleTarifu: dilnaPodleTarifu,
    prirazeno: prirazeno == null ? this.prirazeno : prirazeno(),
    nepritomnosti: nepritomnosti ?? this.nepritomnosti,
  );

  factory ClovekKapacity.fromJson(Map<String, dynamic> json) => ClovekKapacity(
    id: json['id'] as int,
    jmeno: json['name'] as String?,
    tarify: [
      for (final t in json['tariffs'] as List<dynamic>? ?? const [])
        t as String,
    ],
    dilnaPodleTarifu: Dilna.zKodu(json['tariffWorkshop'] as String?),
    prirazeno: json['assigned'] as String?,
    nepritomnosti: [
      for (final n in json['absences'] as List<dynamic>? ?? const [])
        NepritomnostCloveka.fromJson(n as Map<String, dynamic>),
    ],
  );
}

/// Ručně zadaná kapacita dílny na jeden den, přebije počet lidí.
class RucniDenKapacity {
  const RucniDenKapacity({
    required this.den,
    required this.dilna,
    required this.aw,
    this.kdo,
  });

  final DateTime den;
  final Dilna dilna;
  final int aw;
  final String? kdo;

  static RucniDenKapacity? zJson(Map<String, dynamic> json) {
    final dilna = Dilna.zKodu(json['workshop'] as String?);
    if (dilna == null) return null;
    return RucniDenKapacity(
      den: DateTime.parse(json['day'] as String),
      dilna: dilna,
      aw: json['aw'] as int,
      kdo: json['by'] as String?,
    );
  }
}

class PrehledKapacity {
  const PrehledKapacity({this.lide = const [], this.dny = const []});

  final List<ClovekKapacity> lide;
  final List<RucniDenKapacity> dny;

  factory PrehledKapacity.fromJson(Map<String, dynamic> json) =>
      PrehledKapacity(
        lide: [
          for (final c in json['people'] as List<dynamic>? ?? const [])
            ClovekKapacity.fromJson(c as Map<String, dynamic>),
        ],
        dny: [
          for (final d in json['days'] as List<dynamic>? ?? const [])
            ?RucniDenKapacity.zJson(d as Map<String, dynamic>),
        ],
      );
}

/// Kapacita dílen po pracovních dnech: přítomní lidé × 90 AW, ruční den má
/// přednost. Dílna bez lidí a bez ručního dne tu není.
Map<DateTime, Map<Dilna, KapacitaDne>> kapacityObdobi(
  List<ClovekKapacity> lide,
  List<RucniDenKapacity> rucni,
  DateTime od,
  DateTime do_,
) {
  final vysledek = <DateTime, Map<Dilna, KapacitaDne>>{};
  for (
    var d = DateTime(od.year, od.month, od.day);
    !d.isAfter(do_);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (jeVikend(d)) continue;
    final den = d;
    for (final dilna in Dilna.values) {
      final vDilne = lide.where((c) => c.dilna == dilna).toList();
      final pritomno = vDilne
          .where(
            (c) => !c.nepritomnosti.any(
              (n) => !n.od.isAfter(den) && !n.do_.isBefore(den),
            ),
          )
          .length;
      final prepsano = rucni
          .where((r) => r.dilna == dilna && r.den == den)
          .firstOrNull;
      if (prepsano == null && vDilne.isEmpty) continue;
      (vysledek[den] ??= {})[dilna] = KapacitaDne(
        aw: prepsano?.aw ?? pritomno * awClovekDen,
        lidi: pritomno,
        rucne: prepsano != null,
      );
    }
  }
  return vysledek;
}

enum JednotkaKapacity { hodiny, aw }

/// Zadaná kapacita na celé AW; `null` = neplatné, nebo mimo rozsah.
int? prevedNaAw(String text, JednotkaKapacity jednotka) {
  final cislo = double.tryParse(text.trim().replaceAll(',', '.'));
  if (cislo == null || !cislo.isFinite || cislo < 0) return null;
  final aw = (jednotka == JednotkaKapacity.hodiny ? cislo * awZaHodinu : cislo)
      .round();
  return aw <= 9999 ? aw : null;
}
