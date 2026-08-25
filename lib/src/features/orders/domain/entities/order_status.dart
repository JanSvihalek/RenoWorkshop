/// Stav servisní zakázky. Pořadí hodnot = pořadí kroků na dílně,
/// posun stavu jde vždy o jeden krok dopředu (viz [next]).
enum OrderStatus {
  received('received', 'Přijato', 'Přijato'),
  diagnostics('diagnostics', 'V diagnostice', 'Diagnostika'),
  waitingForParts('waiting_for_parts', 'Čeká na díly', 'Čeká na díly'),
  inRepair('in_repair', 'V opravě', 'V opravě'),
  qualityCheck('quality_check', 'Kontrola kvality', 'Kontrola'),
  readyForPickup('ready_for_pickup', 'Připraveno k vyzvednutí', 'Připraveno'),
  pickedUp('picked_up', 'Vyzvednuto', 'Vyzvednuto');

  const OrderStatus(this.apiValue, this.label, this.shortLabel);

  /// Stabilní klíč pro serializaci.
  final String apiValue;

  /// Plný název stavu (badge, timeline).
  final String label;

  /// Zkrácený název pro filtrovací chip.
  final String shortLabel;

  /// Pozice ve stavovém poli (0 = Přijato).
  int get step => index;

  /// Následující stav, nebo `null` u uzavřené zakázky.
  OrderStatus? get next =>
      index < OrderStatus.values.length - 1 ? OrderStatus.values[index + 1] : null;

  /// Zakázka je hotová a předaná - dál se neposouvá.
  bool get isClosed => this == OrderStatus.pickedUp;

  /// Vozidlo je hotové, termín už nemá smysl hlídat.
  bool get isFinished =>
      this == OrderStatus.readyForPickup || this == OrderStatus.pickedUp;

  /// Zakázka je blokovaná (čeká se na někoho jiného).
  bool get isBlocked => this == OrderStatus.waitingForParts;

  static OrderStatus fromApiValue(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => throw ArgumentError('Neznámý stav zakázky: $value'),
    );
  }
}
