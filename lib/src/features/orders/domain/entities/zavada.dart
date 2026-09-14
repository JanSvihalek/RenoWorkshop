/// Závada (úkon) na zakázce z Heliosu. Jen ke čtení - zapisuje ji poradce
/// v Heliosu, dílna ji v aplikaci vidí.
class Zavada {
  const Zavada({required this.id, this.kod, required this.text});

  final String id;

  /// Číslo závady v Heliosu (`reference_subjektu`), pokud je vyplněné.
  final String? kod;

  /// Popis závady tak, jak ho poradce zapsal. Může mít víc řádků.
  final String text;

  factory Zavada.fromJson(Map<String, dynamic> json) {
    final kod = (json['code'] as String?)?.trim();
    return Zavada(
      id: json['id'] as String,
      kod: kod == null || kod.isEmpty ? null : kod,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'code': kod, 'text': text};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Zavada &&
          other.id == id &&
          other.kod == kod &&
          other.text == text);

  @override
  int get hashCode => Object.hash(id, kod, text);
}
