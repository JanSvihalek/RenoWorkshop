/// Přání zákazníka ze zakázkového listu v Heliosu - co má mechanik kromě
/// závad na voze udělat. `null` = v Heliosu nezadáno.
class PraniZakaznika {
  const PraniZakaznika({
    this.myti,
    this.mytiProgram,
    this.vratitDily,
    this.provozniKapaliny,
  });

  factory PraniZakaznika.zJson(Map<String, dynamic> json) => PraniZakaznika(
    myti: json['wash'] as bool?,
    mytiProgram: json['washProgram'] as String?,
    vratitDily: json['returnParts'] as bool?,
    provozniKapaliny: json['operatingFluids'] as bool?,
  );

  final bool? myti;

  /// Přeložený program - `P3`, `Vysát`. Jen u objednaného mytí.
  final String? mytiProgram;
  final bool? vratitDily;
  final bool? provozniKapaliny;
}
