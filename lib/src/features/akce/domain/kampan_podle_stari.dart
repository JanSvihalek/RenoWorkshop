/// Kampaň podle stáří vozu od první registrace - FitServis+ a podobné.
///
/// Vůz do ní spadá, když je mu aspoň [odMesicu] celých měsíců a (je-li
/// vyplněno) méně než [doMesicu]. Vyhodnocuje server; aplikace jen
/// ukazuje výsledek u zakázky a správci tady pravidlo upravují.
class KampanPodleStari {
  const KampanPodleStari({
    this.id,
    required this.nazev,
    this.text = '',
    required this.odMesicu,
    this.doMesicu,
    this.aktivni = true,
  });

  /// `null` u kampaně, která se teprve zakládá.
  final String? id;
  final String nazev;
  final String text;
  final int odMesicu;
  final int? doMesicu;

  /// Vypnutá se u vozů neukazuje. Nemaže se, ať jde zase zapnout.
  final bool aktivni;

  /// „od 48 měsíců", „od 48 do 96 měsíců".
  String get rozsah => doMesicu == null
      ? 'Vozy od $odMesicu měsíců'
      : 'Vozy od $odMesicu do $doMesicu měsíců';

  factory KampanPodleStari.fromJson(Map<String, dynamic> json) =>
      KampanPodleStari(
        id: json['id'] as String?,
        nazev: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        odMesicu: (json['fromMonths'] as num?)?.toInt() ?? 0,
        doMesicu: (json['toMonths'] as num?)?.toInt(),
        aktivni: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'title': nazev,
    'text': text,
    'fromMonths': odMesicu,
    'toMonths': doMesicu,
    'active': aktivni,
  };

  KampanPodleStari copyWith({String? id}) => KampanPodleStari(
    id: id ?? this.id,
    nazev: nazev,
    text: text,
    odMesicu: odMesicu,
    doMesicu: doMesicu,
    aktivni: aktivni,
  );
}

/// Kampaně podle stáří a jestli je přihlášený smí upravovat.
class PrehledKampaniStari {
  const PrehledKampaniStari({
    required this.kampane,
    required this.muzeUpravovat,
  });

  final List<KampanPodleStari> kampane;
  final bool muzeUpravovat;

  factory PrehledKampaniStari.fromJson(Map<String, dynamic> json) =>
      PrehledKampaniStari(
        muzeUpravovat: json['canEdit'] as bool? ?? false,
        kampane: [
          for (final k in json['campaigns'] as List<dynamic>? ?? const [])
            KampanPodleStari.fromJson(k as Map<String, dynamic>),
        ],
      );
}
