/// Pobočka RENOCAR, na které zakázka fyzicky leží.
enum Branch {
  praha('praha', 'Praha'),
  brno('brno', 'Brno'),
  zlin('zlin', 'Zlín');

  const Branch(this.apiValue, this.label);

  /// Stabilní klíč pro serializaci (mock JSON dnes, REST API zítra).
  final String apiValue;

  /// Název pro UI.
  final String label;

  static Branch fromApiValue(String value) {
    return Branch.values.firstWhere(
      (branch) => branch.apiValue == value,
      orElse: () => throw ArgumentError('Neznámá pobočka: $value'),
    );
  }
}
