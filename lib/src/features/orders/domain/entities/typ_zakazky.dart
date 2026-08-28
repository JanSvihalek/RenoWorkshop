/// Typ zakázky - běžná, interní, klempířská a další.
///
/// Číselník je v Heliosu a rozšiřuje se tam, ne v aplikaci: proto sem
/// přichází jako kód a název, stejně jako útvar. Kdyby přibyl další typ,
/// objeví se v appce sám a nemusí se kvůli tomu vydávat nová verze.
///
/// Smí chybět - stará zakázka nebo taková, kde ho poradce nevyplnil.
class TypZakazky {
  const TypZakazky({required this.kod, required this.nazev});

  /// Kód z číselníku Heliosu.
  final String kod;

  /// Název pro UI. Když ho Helios nemá, použije se kód.
  final String nazev;

  factory TypZakazky.fromJson(Map<String, dynamic> json) {
    final nazev = json['label'] as String?;
    return TypZakazky(
      kod: json['code'] as String,
      nazev: nazev != null && nazev.trim().isNotEmpty
          ? nazev.trim()
          : json['code'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'code': kod, 'label': nazev};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TypZakazky && other.kod == kod);

  @override
  int get hashCode => kod.hashCode;

  @override
  String toString() => 'TypZakazky($kod, $nazev)';
}
