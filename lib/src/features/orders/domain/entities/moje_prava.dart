/// Práva přihlášeného - role a pořadače (`GET /me`).
///
/// Jen aby appka neukazovala, co uživatel nesmí; hlídá to služba (zápis
/// bez práva odmítne s hláškou). Admin smí všechno. User má u pořadače
/// `W` (čtení i zápis), `R` (jen čtení), nebo nic - zakázky pořadače bez
/// práva mu služba vůbec nepošle.
class MojePrava {
  const MojePrava({required this.role, required this.poradace});

  /// Bez omezení - ukázková data a starší služba bez `/me`.
  static const vse = MojePrava(role: 'admin', poradace: {});

  /// `admin` nebo `user`.
  final String role;

  /// Kód pořadače (`10026`) -> `R` nebo `W`.
  final Map<String, String> poradace;

  bool get jeAdmin => role == 'admin';

  /// Uživatel zatím nemá žádný pořadač - nemá co vidět.
  bool get bezPristupu => !jeAdmin && poradace.isEmpty;

  /// Smí u zakázky z pořadače [kod] zapisovat (stav, poznámka, plán…)?
  bool smiZapisovat(String? kod) =>
      jeAdmin || (kod != null && poradace[kod] == 'W');

  factory MojePrava.fromJson(Map<String, dynamic> json) => MojePrava(
    role: json['role'] == 'admin' ? 'admin' : 'user',
    poradace: {
      for (final f in json['folders'] as List<dynamic>? ?? const [])
        if (f is Map<String, dynamic> && f['code'] is String)
          f['code'] as String: f['access'] == 'W' ? 'W' : 'R',
    },
  );
}
