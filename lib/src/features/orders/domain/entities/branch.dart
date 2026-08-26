/// Pobočka a útvar, na kterém zakázka leží.
///
/// V Heliosu je uložený jen **útvar** (`subjekty.reference_subjektu`),
/// pětimístný kód typu `12211`. Pobočka se z něj odvozuje **druhou číslicí**:
/// 1 Brno · 2 Čestlice · 3 Kongresové Centrum · 4 Česká · 5 Bubeneč.
///
/// Odvození dělá API, ne appka - kdyby se pravidlo změnilo nebo přibyla
/// pobočka, nemusí se kvůli tomu vydávat nová verze aplikace. Sem přichází
/// obojí už hotové, jako kód a název.
///
/// Obojí smí chybět: zakázka bez vyplněného zpracovatele nemá útvar,
/// a útvar s neznámou druhou číslicí nemá pobočku.
class Branch {
  const Branch({required this.code, required this.label});

  /// Druhá číslice útvaru, např. `2`.
  final String code;

  /// Název pro UI, např. `Čestlice`.
  final String label;

  factory Branch.fromJson(Map<String, dynamic> json) =>
      Branch(code: json['code'] as String, label: json['label'] as String);

  Map<String, dynamic> toJson() => {'code': code, 'label': label};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Branch && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Branch($code, $label)';
}

/// Útvar - jemnější dělení než pobočka, na jedné pobočce jich je víc
/// (podle značky a druhu provozu).
class Department {
  const Department({required this.code, required this.label});

  /// Celý kód z Heliosu, např. `12211`.
  final String code;

  /// Název z číselníku. Když ho Helios nemá, použije se kód.
  final String label;

  factory Department.fromJson(Map<String, dynamic> json) => Department(
    code: json['code'] as String,
    label: (json['label'] as String?)?.trim().isNotEmpty == true
        ? json['label'] as String
        : json['code'] as String,
  );

  Map<String, dynamic> toJson() => {'code': code, 'label': label};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Department && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Department($code, $label)';
}
