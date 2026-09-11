/// Dílenský stav zakázky — jeden záznam v historii.
///
/// Stav se **přidává, neposouvá**. Oprava po bouračce běží týdny a stavy
/// se vracejí (pojišťovna vrátí rozpočet, díl dorazí poškozený), takže
/// jeden přepisovaný údaj by zahodil to nejcennější: kdy se co stalo
/// a jak dlouho se na co čekalo.
///
/// Poslední záznam je ten platný.
class DilenskyStav {
  const DilenskyStav({required this.nazev, this.kod, this.autor, this.zadano});

  /// Kód z číselníku, nebo `null` u ručně zapsaného stavu („Jiný").
  final String? kod;

  /// Text stavu tak, jak se má zobrazit. U číselníkového stavu je to jeho
  /// název **v době zápisu** — přejmenování v číselníku nemění historii.
  final String nazev;

  /// Kdo stav zapsal. `null` u záznamů převedených ze starých dat.
  final String? autor;

  final DateTime? zadano;

  /// Stav mimo číselník, napsaný ručně.
  bool get jeVlastni => kod == null;

  factory DilenskyStav.fromJson(Map<String, dynamic> json) {
    final zadano = json['createdAt'] as String?;
    return DilenskyStav(
      kod: json['code'] as String?,
      nazev: json['label'] as String,
      autor: json['author'] as String?,
      zadano: zadano == null ? null : DateTime.tryParse(zadano),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': kod,
    'label': nazev,
    'author': autor,
    'createdAt': zadano?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DilenskyStav &&
          other.kod == kod &&
          other.nazev == nazev &&
          other.zadano == zadano);

  @override
  int get hashCode => Object.hash(kod, nazev, zadano);

  @override
  String toString() => 'DilenskyStav($nazev)';
}

/// Položka nabídky stavů. Číselník žije na serveru, takže nový stav se
/// v aplikaci objeví sám — bez nové verze v telefonech.
class NabidkaStavu {
  const NabidkaStavu({required this.kod, required this.nazev});

  final String kod;
  final String nazev;

  factory NabidkaStavu.fromJson(Map<String, dynamic> json) =>
      NabidkaStavu(kod: json['code'] as String, nazev: json['label'] as String);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NabidkaStavu && other.kod == kod);

  @override
  int get hashCode => kod.hashCode;
}
