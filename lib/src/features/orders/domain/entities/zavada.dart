/// Závada (úkon) na zakázce z Heliosu. Jen ke čtení - zapisuje ji poradce
/// v Heliosu, dílna ji v aplikaci vidí.
class Zavada {
  const Zavada({required this.id, this.kod, this.nazev, required this.text});

  final String id;

  /// Číslo závady v Heliosu (`reference_subjektu`), pokud je vyplněné.
  final String? kod;

  /// Stručný popis závady (`nazev_subjektu`) - podle něj ji dílna pozná.
  /// `null`, když ho Helios nemá nebo ho server ještě neposílá.
  final String? nazev;

  /// Podrobnosti (poznámka) tak, jak je poradce rozepsal. Může mít víc
  /// řádků.
  final String text;

  factory Zavada.fromJson(Map<String, dynamic> json) {
    final kod = (json['code'] as String?)?.trim();
    final nazev = (json['title'] as String?)?.trim();
    return Zavada(
      id: json['id'] as String,
      kod: kod == null || kod.isEmpty ? null : kod,
      nazev: nazev == null || nazev.isEmpty ? null : nazev,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': kod,
    'title': nazev,
    'text': text,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Zavada &&
          other.id == id &&
          other.kod == kod &&
          other.nazev == nazev &&
          other.text == text);

  @override
  int get hashCode => Object.hash(id, kod, nazev, text);
}
