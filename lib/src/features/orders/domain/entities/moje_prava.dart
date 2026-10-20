/// Práva přihlášeného - role, pořadače a pobočky plánovače (`GET /me`).
///
/// Jen aby appka neukazovala, co uživatel nesmí; hlídá to služba (zápis
/// bez práva odmítne s hláškou). Admin smí všechno. User má u pořadače
/// `W` (čtení i zápis), `R` (jen čtení), nebo nic - zakázky pořadače bez
/// práva mu služba vůbec nepošle.
///
/// Plánovač klempírny má práva úplně zvlášť, po pobočkách ([planovac]):
/// `W` plánovat (plán i dílenský stav v plánovači), `R` prohlížet, nebo
/// nic. Pořadače do plánovače nemluví.
class MojePrava {
  const MojePrava({
    required this.role,
    required this.poradace,
    this.planovac = const {},
  });

  /// Bez omezení - ukázková data a starší služba bez `/me`.
  static const vse = MojePrava(role: 'admin', poradace: {});

  /// `admin` nebo `user`.
  final String role;

  /// Kód pořadače (`10026`) -> `R` nebo `W`.
  final Map<String, String> poradace;

  /// Kód pobočky plánovače (`1`) -> `W` plánovat, `R` prohlížet. Chybí =
  /// pobočku v plánovači nevidí.
  final Map<String, String> planovac;

  bool get jeAdmin => role == 'admin';

  /// Vidí plánovač vůbec - má v něm aspoň jednu pobočku?
  bool get vidiPlanovac => jeAdmin || planovac.isNotEmpty;

  /// Uživatel zatím nemá žádný pořadač - nemá co vidět.
  bool get bezPristupu => !jeAdmin && poradace.isEmpty;

  /// Vidí zakázky pořadače [kod] - jde otevřít detail?
  bool smiCist(String? kod) =>
      jeAdmin || (kod != null && poradace.containsKey(kod));

  /// Smí u zakázky z pořadače [kod] zapisovat (stav, poznámka…)?
  bool smiZapisovat(String? kod) =>
      jeAdmin || (kod != null && poradace[kod] == 'W');

  /// Smí v plánovači u pobočky [pobocka] plánovat - plán i dílenský stav?
  bool smiPlanovat(String? pobocka) =>
      jeAdmin || (pobocka != null && planovac[pobocka] == 'W');

  factory MojePrava.fromJson(Map<String, dynamic> json) => MojePrava(
    role: json['role'] == 'admin' ? 'admin' : 'user',
    poradace: _prava(json['folders']),
    planovac: _prava(json['planner']),
  );

  /// `[{code, access}]` -> kód -> `R`/`W`.
  static Map<String, String> _prava(Object? seznam) => {
    if (seznam is List<dynamic>)
      for (final f in seznam)
        if (f is Map<String, dynamic> && f['code'] is String)
          f['code'] as String: f['access'] == 'W' ? 'W' : 'R',
  };
}
