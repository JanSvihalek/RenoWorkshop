import 'package:flutter/foundation.dart';

/// Dezén pneu z příjmu - hloubka u každého kola v mm a letní / zimní.
///
/// Stejná pravidla jako služba (RenoWorkshopApi src/domain/pneu.ts). Do
/// příjmu se ukládá krátce: `Z;5.2;4.8;3.1;6` - druh a kola LP, PP, LZ, PZ.
///
/// Hodnocení kola:
///   v pořádku    od 4 mm
///   doporučeno   pod 4 mm (zimní minimum)
///   nutné        pod 1,6 mm (zákonné minimum), u zimních pod 4 mm
@immutable
class Dezen {
  const Dezen({this.zimni = false, this.lp, this.pp, this.lz, this.pz});

  final bool zimni;

  /// mm; `null` = nezměřeno.
  final double? lp;
  final double? pp;
  final double? lz;
  final double? pz;

  static const zimniMinimum = 4.0;
  static const zakonneMinimum = 1.6;

  /// Víc mají nejvýš nové pneu - překlep („52" místo „5,2").
  static const maximum = 20.0;

  /// Kola v pořadí LP, PP, LZ, PZ s popiskem.
  List<(String, double?)> get kola => [
    ('LP', lp),
    ('PP', pp),
    ('LZ', lz),
    ('PZ', pz),
  ];

  bool get jeKompletni => kola.every((k) => k.$2 != null);

  /// Nejhorší kolo; nezměřená se nepočítají. `null` = nic nezměřeno.
  StavDezenu? get stav {
    final stavy = [
      for (final (_, mm) in kola)
        if (mm != null) stavKola(mm),
    ];
    if (stavy.isEmpty) return null;
    if (stavy.contains(StavDezenu.nutne)) return StavDezenu.nutne;
    if (stavy.contains(StavDezenu.doporuceno)) return StavDezenu.doporuceno;
    return StavDezenu.ok;
  }

  StavDezenu stavKola(double mm) {
    if (mm < zakonneMinimum || (zimni && mm < zimniMinimum)) {
      return StavDezenu.nutne;
    }
    return mm < zimniMinimum ? StavDezenu.doporuceno : StavDezenu.ok;
  }

  /// „Zimní · LP 5,2 · PP 4,8 · LZ 3,1 · PZ 6,0 mm".
  String get popis =>
      '${zimni ? 'Zimní' : 'Letní'} · '
      '${[for (final (nazev, hodnota) in kola) '$nazev ${hodnota == null ? '–' : formatMm(hodnota)}'].join(' · ')} mm';

  /// `Z;5.2;4.8;3.1;6` do příjmu.
  String zapis() => [
    zimni ? 'Z' : 'L',
    for (final (_, mm) in kola) mm == null ? '' : _cislo(mm),
  ].join(';');

  /// Ze zápisu příjmu; nečitelný `null`.
  static Dezen? precti(String? hodnota) {
    final casti = hodnota?.split(';');
    if (casti == null || casti.length != 5) return null;
    if (casti[0] != 'L' && casti[0] != 'Z') return null;
    final kola = <double?>[];
    for (final text in casti.skip(1)) {
      if (text.trim().isEmpty) {
        kola.add(null);
        continue;
      }
      final mm = double.tryParse(text.trim());
      if (mm == null || mm < 0 || mm > maximum) return null;
      kola.add(mm);
    }
    return Dezen(
      zimni: casti[0] == 'Z',
      lp: kola[0],
      pp: kola[1],
      lz: kola[2],
      pz: kola[3],
    );
  }

  /// Z API karty vozu (`tires`): `wheels` fl, fr, rl, rr.
  static Dezen? zApi(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kola = json['wheels'];
    if (kola is! Map<String, dynamic>) return null;
    double? mm(String klic) => (kola[klic] as num?)?.toDouble();
    return Dezen(
      zimni: json['winter'] == true,
      lp: mm('fl'),
      pp: mm('fr'),
      lz: mm('rl'),
      pz: mm('rr'),
    );
  }

  /// Text z pole na obrazovce („5,2", „5.2") -> mm; prázdné `null`,
  /// nesmyslné vyhodí [FormatException].
  static double? zTextu(String text) {
    final upraveny = text.trim().replaceAll(',', '.');
    if (upraveny.isEmpty) return null;
    final mm = double.tryParse(upraveny);
    if (mm == null || mm < 0 || mm > maximum) {
      throw FormatException('Dezén $text mm není možný.');
    }
    return (mm * 10).roundToDouble() / 10;
  }

  static String _cislo(double mm) =>
      mm == mm.roundToDouble() ? mm.toInt().toString() : mm.toString();

  @override
  bool operator ==(Object other) =>
      other is Dezen &&
      other.zimni == zimni &&
      other.lp == lp &&
      other.pp == pp &&
      other.lz == lz &&
      other.pz == pz;

  @override
  int get hashCode => Object.hash(zimni, lp, pp, lz, pz);
}

/// „5,2" - jedno desetinné místo, česky.
String formatMm(double mm) => mm.toStringAsFixed(1).replaceAll('.', ',');

enum StavDezenu {
  ok('V pořádku'),
  doporuceno('Doporučena výměna'),
  nutne('Nutná výměna');

  const StavDezenu(this.label);

  final String label;
}
