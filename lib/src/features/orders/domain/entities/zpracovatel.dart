import 'branch.dart';

/// Kdo má zakázku právě na starosti - zpracovatel.
///
/// Na rozdíl od „Zodpovídá" (vede Helios) ho vede dílna v aplikaci
/// a mění se během opravy. Jeden člověk na zakázku; do Heliosu se nevrací.
class Zpracovatel {
  const Zpracovatel({
    required this.id,
    required this.jmeno,
    this.email,
    this.od,
    this.prirazilKdo,
  });

  /// `cislo_subjektu` zaměstnance v Heliosu.
  final int id;
  final String jmeno;

  /// Podle e-mailu se pozná, že zakázku zpracovávám já.
  final String? email;

  /// Odkdy zakázku zpracovává.
  final DateTime? od;

  /// Kdo ho přiřadil - u převzetí on sám.
  final String? prirazilKdo;

  factory Zpracovatel.fromJson(Map<String, dynamic> json) => Zpracovatel(
    id: (json['id'] as num).toInt(),
    jmeno: json['name'] as String? ?? '',
    email: json['email'] as String?,
    od: DateTime.tryParse(json['since'] as String? ?? ''),
    prirazilKdo: json['assignedBy'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': jmeno,
    'email': email,
    'since': od?.toIso8601String().substring(0, 19),
    'assignedBy': prirazilKdo,
  };

  /// Je to přihlášený uživatel? E-maily se v Heliosu i v Microsoft účtu
  /// píší různě velkými písmeny.
  bool jeEmail(String? jiny) {
    final muj = email?.trim().toLowerCase();
    return muj != null && muj.isNotEmpty && muj == jiny?.trim().toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Zpracovatel && other.id == id && other.od == od);

  @override
  int get hashCode => Object.hash(id, od);
}

/// Zaměstnanec z Heliosu v nabídce zpracovatelů.
class ZamestnanecKVyberu {
  const ZamestnanecKVyberu({
    required this.id,
    required this.jmeno,
    this.kod,
    this.email,
    this.utvar,
  });

  final int id;
  final String jmeno;
  final String? kod;
  final String? email;
  final Department? utvar;

  factory ZamestnanecKVyberu.fromJson(Map<String, dynamic> json) =>
      ZamestnanecKVyberu(
        id: (json['id'] as num).toInt(),
        jmeno: json['name'] as String? ?? '',
        kod: json['code'] as String?,
        email: json['email'] as String?,
        utvar: json['department'] is Map<String, dynamic>
            ? Department.fromJson(json['department'] as Map<String, dynamic>)
            : null,
      );
}

/// Koho lze zakázce přiřadit: lidé z jejího útvaru, nebo všichni.
class NabidkaZpracovatelu {
  const NabidkaZpracovatelu({
    required this.lide,
    this.utvarZakazky,
    this.jenUtvar = false,
  });

  final List<ZamestnanecKVyberu> lide;

  /// Útvar zakázky, podle kterého se nabídka filtrovala.
  final Department? utvarZakazky;

  /// Jsou v nabídce jen lidé z útvaru zakázky? `false` = všichni
  /// (na požádání, nebo zakázka útvar nemá).
  final bool jenUtvar;

  factory NabidkaZpracovatelu.fromJson(Map<String, dynamic> json) =>
      NabidkaZpracovatelu(
        lide: (json['employees'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  ZamestnanecKVyberu.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        utvarZakazky: json['department'] is Map<String, dynamic>
            ? Department.fromJson(json['department'] as Map<String, dynamic>)
            : null,
        jenUtvar: json['filtered'] as bool? ?? false,
      );
}
