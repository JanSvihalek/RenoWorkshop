import 'package:flutter/foundation.dart';

/// Uloženka pneu z Heliosu - sada, kterou zákazník nechal u nás ve skladu
/// (`GET /orders/{id}/tire-storage`, v kartě vozu `tireStorage`). Vůz jich
/// může mít libovolně mnoho, sezóny se střídají.
@immutable
class UlozenkaPneu {
  const UlozenkaPneu({
    required this.id,
    required this.cislo,
    this.stav,
    this.aktivni = true,
    this.zimni,
    this.pocet,
    this.ulozeno,
    this.vratitDo,
    this.vraceno,
    this.umisteni,
    this.poznamka,
    this.zTetoZakazky = false,
    this.kola = const [],
  });

  final int id;

  /// Číslo uloženky (UCLII002727) - na štítku u pneu.
  final String cislo;

  /// Zaveden, Uložen, Ukončen, Zrušen, Editace, Přijmuto.
  final String? stav;

  /// Leží u nás - ne ukončená ani zrušená.
  final bool aktivni;

  /// `true` zimní, `false` letní, `null` neuvedeno.
  final bool? zimni;
  final int? pocet;
  final DateTime? ulozeno;
  final DateTime? vratitDo;
  final DateTime? vraceno;

  /// Místo ve skladu (regál).
  final String? umisteni;
  final String? poznamka;

  /// Založená na zakázce, ze které se detail ptá.
  final bool zTetoZakazky;
  final List<KoloUlozenky> kola;

  factory UlozenkaPneu.fromJson(Map<String, dynamic> json) {
    final stav = json['status'];
    return UlozenkaPneu(
      id: (json['id'] as num).toInt(),
      cislo: json['number'] as String? ?? '${json['id']}',
      stav: stav is Map<String, dynamic> ? stav['label'] as String? : null,
      aktivni: json['active'] as bool? ?? true,
      zimni: switch (json['season']) {
        'winter' => true,
        'summer' => false,
        _ => null,
      },
      pocet: (json['count'] as num?)?.toInt(),
      ulozeno: _datum(json['storedAt']),
      vratitDo: _datum(json['returnPlannedAt']),
      vraceno: _datum(json['returnedAt']),
      umisteni: json['location'] as String?,
      poznamka: json['note'] as String?,
      zTetoZakazky: json['thisOrder'] as bool? ?? false,
      kola: [
        for (final k in json['wheels'] as List<dynamic>? ?? const [])
          KoloUlozenky.fromJson(k as Map<String, dynamic>),
      ],
    );
  }

  static DateTime? _datum(Object? hodnota) =>
      hodnota is String ? DateTime.tryParse(hodnota) : null;
}

/// Kolo uloženky - LP, LZ, PP, PZ, nebo rezerva.
@immutable
class KoloUlozenky {
  const KoloUlozenky({
    required this.pozice,
    this.vyrobce,
    this.vzorek,
    this.rozmer,
    this.dezen,
    this.dot,
    this.indexRychlosti,
    this.indexNosnosti,
    this.poskozeni,
  });

  /// LP, PP, LZ, PZ nebo Rezerva.
  final String pozice;
  final String? vyrobce;
  final String? vzorek;
  final String? rozmer;

  /// mm
  final double? dezen;
  final String? dot;
  final String? indexRychlosti;
  final int? indexNosnosti;
  final String? poskozeni;

  /// „NEXEN Nfera Sport".
  String get pneu => [?vyrobce, ?vzorek].join(' ');

  /// „225/55 R18 · 102Y · DOT 2525".
  String get udaje => [
    ?rozmer,
    if (indexNosnosti != null && indexRychlosti != null)
      '$indexNosnosti$indexRychlosti',
    if (dot != null) 'DOT $dot',
  ].join(' · ');

  factory KoloUlozenky.fromJson(Map<String, dynamic> json) => KoloUlozenky(
    pozice: switch (json['position']) {
      'fl' => 'LP',
      'fr' => 'PP',
      'rl' => 'LZ',
      'rr' => 'PZ',
      'spare' => 'Rezerva',
      final Object? jina => '$jina',
    },
    vyrobce: json['brand'] as String?,
    vzorek: json['pattern'] as String?,
    rozmer: json['size'] as String?,
    dezen: (json['tread'] as num?)?.toDouble(),
    dot: json['dot'] as String?,
    indexRychlosti: json['speedIndex'] as String?,
    indexNosnosti: (json['loadIndex'] as num?)?.toInt(),
    poskozeni: json['damage'] as String?,
  );
}
