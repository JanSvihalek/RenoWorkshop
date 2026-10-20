/// Správa uživatelů (jen admin) - kdo má jakou roli a práva k pořadačům.
/// Stejná data jako stránka Uživatelé na webu (`GET/PUT /users`).
library;

import '../../orders/domain/entities/moje_prava.dart';

/// Pořadač s pobočkou - v detailu uživatele se podle ní seskupují.
class PoradacSpravy {
  const PoradacSpravy({
    required this.kod,
    required this.nazev,
    this.pobockaKod,
    this.pobockaNazev,
  });

  final String kod;
  final String nazev;
  final String? pobockaKod;
  final String? pobockaNazev;

  factory PoradacSpravy.fromJson(Map<String, dynamic> json) {
    final pobocka = json['branch'];
    return PoradacSpravy(
      kod: json['code'] as String,
      nazev: json['label'] as String? ?? json['code'] as String,
      pobockaKod: pobocka is Map<String, dynamic>
          ? pobocka['code'] as String?
          : null,
      pobockaNazev: pobocka is Map<String, dynamic>
          ? pobocka['label'] as String?
          : null,
    );
  }
}

class UzivatelSpravy {
  const UzivatelSpravy({
    required this.email,
    this.jmeno,
    this.role = 'user',
    this.prihlasen,
    this.prava = const {},
    this.planovac = 'cist',
  });

  final String email;
  final String? jmeno;

  /// `admin` nebo `user`.
  final String role;
  final DateTime? prihlasen;

  /// Kód pořadače -> `R` (čtení) nebo `W` (zápis). Chybí = nic.
  final Map<String, String> prava;

  /// Plánovač: `planovat`, `cist` (výchozí), `zadne`. Admin plánuje vždy.
  final String planovac;

  bool get jeAdmin => role == 'admin';

  /// Jméno, nebo aspoň e-mail.
  String get popisek => jmeno?.trim().isNotEmpty == true ? jmeno! : email;

  UzivatelSpravy copyWith({
    String? role,
    Map<String, String>? prava,
    String? planovac,
  }) => UzivatelSpravy(
    email: email,
    jmeno: jmeno,
    role: role ?? this.role,
    prihlasen: prihlasen,
    prava: prava ?? this.prava,
    planovac: planovac ?? this.planovac,
  );

  factory UzivatelSpravy.fromJson(Map<String, dynamic> json) => UzivatelSpravy(
    email: json['email'] as String,
    jmeno: json['name'] as String?,
    role: json['role'] == 'admin' ? 'admin' : 'user',
    prihlasen: DateTime.tryParse(json['lastLoginAt'] as String? ?? ''),
    planovac: planovacZApi(json['planner']),
    prava: {
      for (final MapEntry(:key, :value)
          in (json['access'] as Map<String, dynamic>? ?? const {}).entries)
        if (value == 'R' || value == 'W') key: value as String,
    },
  );
}

class PrehledUzivatelu {
  const PrehledUzivatelu({required this.poradace, required this.uzivatele});

  final List<PoradacSpravy> poradace;
  final List<UzivatelSpravy> uzivatele;

  factory PrehledUzivatelu.fromJson(Map<String, dynamic> json) =>
      PrehledUzivatelu(
        poradace: [
          for (final p in json['folders'] as List<dynamic>? ?? const [])
            PoradacSpravy.fromJson(p as Map<String, dynamic>),
        ],
        uzivatele: [
          for (final u in json['users'] as List<dynamic>? ?? const [])
            UzivatelSpravy.fromJson(u as Map<String, dynamic>),
        ],
      );
}

/// Pořadače po pobočkách, v pořadí, jak přišly - (název pobočky, pořadače).
List<(String, List<PoradacSpravy>)> poradacePoPobockach(
  List<PoradacSpravy> poradace,
) {
  final skupiny = <String, List<PoradacSpravy>>{};
  for (final p in poradace) {
    (skupiny[p.pobockaNazev ?? 'Bez pobočky'] ??= []).add(p);
  }
  return [for (final e in skupiny.entries) (e.key, e.value)];
}

/// Krátké shrnutí práv do seznamu: „Brno: zápis · Čestlice: čtení".
/// Pobočka s různými právy u svých pořadačů je „částečně".
String souhrnPrav(UzivatelSpravy uzivatel, List<PoradacSpravy> poradace) {
  if (uzivatel.jeAdmin) return 'Admin · vše';
  final casti = <String>[];
  for (final (pobocka, seznam) in poradacePoPobockach(poradace)) {
    final prava = [for (final p in seznam) uzivatel.prava[p.kod]];
    if (prava.every((p) => p == null)) continue;
    final text = prava.every((p) => p == 'W')
        ? 'zápis'
        : prava.every((p) => p == 'R')
        ? 'čtení'
        : 'částečně';
    casti.add('$pobocka: $text');
  }
  if (casti.isEmpty) return 'Bez přístupu';
  if (uzivatel.planovac == 'planovat') casti.add('plánuje');
  return casti.join(' · ');
}
