import '../../orders/domain/entities/plan_klempirny.dart';
import 'prehled_planu.dart';

/// Kapacita dílen - kdo kam patří, kdy chybí a ručně zadané dny. Stejná
/// pravidla jako služba (`domain/kapacita-planu.ts`), jen s právem Kapacita.

/// Zařazení mimo dílny: člověk se do kapacity nepočítá.
const zarazeniMimo = 'mimo';

/// Výchozí kapacita člověka za den: 7,5 hodiny práce.
const awClovekDen = 90;

/// Nejvyšší kapacita člověka za den: 24 hodin.
const awClovekMax = 288;

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
    this.awDen = awClovekDen,
    this.nepritomnosti = const [],
  });

  final int id;
  final String? jmeno;
  final List<String> tarify;

  /// Kam patří podle tarifu z Heliosu.
  final Dilna? dilnaPodleTarifu;

  /// Ruční zařazení: kód dílny, nebo [zarazeniMimo]. `null` = podle tarifu.
  final String? prirazeno;

  /// Kapacita člověka za den v AW (třeba zkrácený úvazek).
  final int awDen;
  final List<NepritomnostCloveka> nepritomnosti;

  /// Kde se opravdu počítá; `null` = nikde.
  Dilna? get dilna {
    if (prirazeno == zarazeniMimo) return null;
    return Dilna.zKodu(prirazeno) ?? dilnaPodleTarifu;
  }

  String get popisek => jmeno ?? 'Zaměstnanec $id';

  ClovekKapacity copyWith({
    String? Function()? prirazeno,
    int? awDen,
    List<NepritomnostCloveka>? nepritomnosti,
  }) => ClovekKapacity(
    id: id,
    jmeno: jmeno,
    tarify: tarify,
    dilnaPodleTarifu: dilnaPodleTarifu,
    prirazeno: prirazeno == null ? this.prirazeno : prirazeno(),
    awDen: awDen ?? this.awDen,
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
    awDen: json['dailyAw'] as int? ?? awClovekDen,
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

/// Kapacita dílen po pracovních dnech: součet přítomných lidí, ruční den má
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
      final pritomni = vDilne
          .where(
            (c) => !c.nepritomnosti.any(
              (n) => !n.od.isAfter(den) && !n.do_.isBefore(den),
            ),
          )
          .toList();
      final prepsano = rucni
          .where((r) => r.dilna == dilna && r.den == den)
          .firstOrNull;
      if (prepsano == null && vDilne.isEmpty) continue;
      (vysledek[den] ??= {})[dilna] = KapacitaDne(
        aw: prepsano?.aw ?? pritomni.fold(0, (soucet, c) => soucet + c.awDen),
        lidi: pritomni.length,
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

/// AW jako text do pole v dané jednotce. Hodiny na dvě desetinná místa, aby se
/// uložením beze změny AW nezměnilo: 27 AW je 2,25 h, ne 2,3 h (to by bylo 28).
String hodnotaKapacity(int aw, JednotkaKapacity jednotka) {
  if (jednotka == JednotkaKapacity.aw) return '$aw';
  final hodiny = (aw / awZaHodinu * 100).round() / 100;
  return (hodiny == hodiny.roundToDouble()
          ? hodiny.toInt().toString()
          : hodiny.toString())
      .replaceAll('.', ',');
}

/// Zadaná kapacita člověka na celé AW. Prázdné pole je návrat na výchozí
/// hodnotu, `null` = neplatné. Nula neplatí: kdo se nepočítá, má Nepočítat.
int? kapacitaClovekaNaAw(String text, JednotkaKapacity jednotka) {
  if (text.trim().isEmpty) return awClovekDen;
  final aw = prevedNaAw(text, jednotka);
  return aw != null && aw >= 1 && aw <= awClovekMax ? aw : null;
}
