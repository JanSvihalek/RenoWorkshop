/// Technická kampaň BMW (svolávací akce), která se týká vozu zakázky -
/// server ji ke zakázce dohledá podle VINu.
class KampanVozidla {
  const KampanVozidla({
    required this.id,
    this.kod,
    required this.nazev,
    this.text = '',
  });

  final String id;

  /// Číslo kampaně od BMW, `null` = nezadané.
  final String? kod;
  final String nazev;

  /// Co se na voze dělá - podrobnosti od správce.
  final String text;

  factory KampanVozidla.fromJson(Map<String, dynamic> json) {
    final kod = (json['code'] as String?)?.trim();
    return KampanVozidla(
      id: json['id'] as String,
      kod: kod == null || kod.isEmpty ? null : kod,
      nazev: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': kod,
    'title': nazev,
    'text': text,
  };
}
