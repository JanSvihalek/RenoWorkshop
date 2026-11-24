/// Poznámka mechanika / servisního poradce k zakázce.
class OrderNote {
  const OrderNote({
    required this.id,
    required this.text,
    required this.author,
    required this.createdAt,
    this.zvyraznena = false,
  });

  final String id;
  final String text;

  /// Kdo poznámku napsal - "Jan Dvořák" nebo "M. Horáková, poradce".
  final String author;
  final DateTime createdAt;

  /// Zvýrazněná - v kartě nahoře a žlutě, ať je na první pohled vidět.
  final bool zvyraznena;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OrderNote && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
