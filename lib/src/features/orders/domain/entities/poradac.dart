/// Pořadač zakázky v Heliosu - v zásadě značka a pobočka zpracování.
///
/// Z Heliosu chodí číslo, krátký název („BMW BSL") drží převodní tabulka
/// na serveru. Když v ní pořadač chybí, přijde jako název samo číslo.
class Poradac {
  const Poradac({required this.kod, required this.nazev});

  /// Číslo pořadače z Heliosu, např. `10026`.
  final String kod;

  /// Krátký název pro UI.
  final String nazev;

  factory Poradac.fromJson(Map<String, dynamic> json) {
    final kod = json['code'] as String;
    final nazev = (json['label'] as String?)?.trim();
    return Poradac(
      kod: kod,
      nazev: nazev == null || nazev.isEmpty ? kod : nazev,
    );
  }

  Map<String, dynamic> toJson() => {'code': kod, 'label': nazev};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Poradac && other.kod == kod);

  @override
  int get hashCode => kod.hashCode;
}
