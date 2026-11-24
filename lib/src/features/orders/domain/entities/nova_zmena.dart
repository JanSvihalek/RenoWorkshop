/// Druh nové změny na zakázce - `kind` ze služby.
enum DruhZmeny {
  stav('status'),
  dokonceno('finished'),
  zruseno('cancelled'),
  upraveno('edited'),
  poznamka('note');

  const DruhZmeny(this.klic);

  /// Hodnota v API.
  final String klic;

  static DruhZmeny? zKlice(String? klic) {
    for (final druh in values) {
      if (druh.klic == klic) return druh;
    }
    return null;
  }
}

/// Nová změna na zakázce pro přihlášeného - štítek „Nový stav" / „Nová
/// poznámka" v seznamu.
///
/// Služba posílá poslední změnu stavu v průběhu nebo poznámku v pracovním
/// listu od někoho jiného, kterou přihlášený ještě neviděl (neotevřel
/// detail). Každý uživatel zvlášť: komu zakázku otevře, tomu štítek zmizí,
/// ostatním zůstane. Vlastní změny se nepočítají. Jako na webu.
class NovaZmena {
  const NovaZmena({
    required this.druh,
    required this.popisek,
    required this.kdy,
    this.kdo,
    this.pocet = 1,
  });

  /// Z `unseenChange`; neznámý druh nebo pokažené datum = `null`.
  static NovaZmena? zJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final druh = DruhZmeny.zKlice(json['kind'] as String?);
    final kdy = DateTime.tryParse(json['at'] as String? ?? '');
    if (druh == null || kdy == null) return null;
    return NovaZmena(
      druh: druh,
      popisek: json['label'] as String? ?? '',
      kdo: json['by'] as String?,
      kdy: kdy,
      pocet: (json['count'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': druh.klic,
    'label': popisek,
    'by': kdo,
    'at': kdy.toIso8601String(),
    'count': pocet,
  };

  final DruhZmeny druh;

  /// Název stavu, nebo začátek poznámky.
  final String popisek;
  final String? kdo;
  final DateTime kdy;

  /// Kolik nových změn celkem - štítek ukáže poslední a „+N".
  final int pocet;

  /// „Nový stav: Lakovna", „Nová poznámka: Volal zákazník".
  String get text => switch (druh) {
    DruhZmeny.stav => 'Nový stav: $popisek',
    DruhZmeny.dokonceno => 'Dokončeno: $popisek',
    DruhZmeny.zruseno => 'Zrušen stav: $popisek',
    DruhZmeny.upraveno => 'Upraven stav: $popisek',
    DruhZmeny.poznamka => 'Nová poznámka: $popisek',
  };

  /// Kdo a kdy: „Eva Malá · 10:05", starší „Eva Malá · 23. 11. 14:30".
  String kdoKdy(DateTime ted) {
    final minuty = kdy.minute.toString().padLeft(2, '0');
    final dnes =
        kdy.year == ted.year && kdy.month == ted.month && kdy.day == ted.day;
    final cas = dnes
        ? '${kdy.hour}:$minuty'
        : '${kdy.day}. ${kdy.month}.${kdy.year == ted.year ? '' : ' ${kdy.year}'} '
              '${kdy.hour}:$minuty';
    return [?kdo, cas].join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NovaZmena &&
          other.druh == druh &&
          other.popisek == popisek &&
          other.kdo == kdo &&
          other.kdy == kdy &&
          other.pocet == pocet);

  @override
  int get hashCode => Object.hash(druh, popisek, kdo, kdy, pocet);
}
