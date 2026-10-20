/// Práva přihlášeného - role a pořadače (`GET /me`).
///
/// Jen aby appka neukazovala, co uživatel nesmí; hlídá to služba (zápis
/// bez práva odmítne s hláškou). Admin smí všechno. User má u pořadače
/// `W` (čtení i zápis), `R` (jen čtení), nebo nic - zakázky pořadače bez
/// práva mu služba vůbec nepošle.
///
/// Plánovač klempírny má úroveň zvlášť ([planovac]): `planovat`,
/// `cist` (výchozí, jen prohlíží), `zadne` (nevidí ho).
class MojePrava {
  const MojePrava({
    required this.role,
    required this.poradace,
    this.planovac = 'cist',
  });

  /// Bez omezení - ukázková data a starší služba bez `/me`.
  static const vse = MojePrava(role: 'admin', poradace: {});

  /// `admin` nebo `user`.
  final String role;

  /// Kód pořadače (`10026`) -> `R` nebo `W`.
  final Map<String, String> poradace;

  /// `planovat`, `cist`, nebo `zadne`. Admin plánuje vždy.
  final String planovac;

  bool get jeAdmin => role == 'admin';

  /// Vidí plánovač vůbec? Úroveň `zadne` ho schová.
  bool get vidiPlanovac => jeAdmin || planovac != 'zadne';

  /// Uživatel zatím nemá žádný pořadač - nemá co vidět.
  bool get bezPristupu => !jeAdmin && poradace.isEmpty;

  /// Smí u zakázky z pořadače [kod] zapisovat (stav, poznámka, plán…)?
  bool smiZapisovat(String? kod) =>
      jeAdmin || (kod != null && poradace[kod] == 'W');

  /// Smí zakázku z pořadače [kod] plánovat (zaplánovat, posunout, zrušit
  /// plán)? Se zápisem k pořadači a plánovačem `planovat`. Dílenský stav
  /// v plánovači se řídí jen pořadačem ([smiZapisovat]).
  bool smiPlanovat(String? kod) =>
      jeAdmin || (planovac == 'planovat' && smiZapisovat(kod));

  factory MojePrava.fromJson(Map<String, dynamic> json) => MojePrava(
    role: json['role'] == 'admin' ? 'admin' : 'user',
    planovac: planovacZApi(json['planner']),
    poradace: {
      for (final f in json['folders'] as List<dynamic>? ?? const [])
        if (f is Map<String, dynamic> && f['code'] is String)
          f['code'] as String: f['access'] == 'W' ? 'W' : 'R',
    },
  );
}

/// Úroveň plánovače z API (`edit`, `view`, `none`); chybí = `cist`.
String planovacZApi(Object? planner) => switch (planner) {
  'edit' => 'planovat',
  'none' => 'zadne',
  _ => 'cist',
};

/// Úroveň plánovače do API.
String planovacDoApi(String planovac) => switch (planovac) {
  'planovat' => 'edit',
  'zadne' => 'none',
  _ => 'view',
};
