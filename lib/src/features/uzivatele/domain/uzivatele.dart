/// Správa uživatelů (jen admin) - kdo má jakou roli a práva k pořadačům.
/// Stejná data jako stránka Uživatelé na webu (`GET/PUT /users`).
library;

import '../../plan/domain/prehled_planu.dart' show PobockaPlanu;

export '../../plan/domain/prehled_planu.dart' show PobockaPlanu;

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
    this.planovac = const {},
    this.kapacita = const {},
  });

  final String email;
  final String? jmeno;

  /// `admin` nebo `user`.
  final String role;
  final DateTime? prihlasen;

  /// Kód pořadače -> `R` (čtení) nebo `W` (zápis). Chybí = nic.
  final Map<String, String> prava;

  /// Plánovač: kód pobočky -> `W` plánovat, `R` prohlížet. Chybí = nic.
  /// Admin plánuje všude.
  final Map<String, String> planovac;

  /// Pobočky, u kterých smí upravovat kapacitu dílen.
  final Set<String> kapacita;

  bool get jeAdmin => role == 'admin';

  /// Jméno, nebo aspoň e-mail.
  String get popisek => jmeno?.trim().isNotEmpty == true ? jmeno! : email;

  UzivatelSpravy copyWith({
    String? role,
    Map<String, String>? prava,
    Map<String, String>? planovac,
    Set<String>? kapacita,
  }) => UzivatelSpravy(
    email: email,
    jmeno: jmeno,
    role: role ?? this.role,
    prihlasen: prihlasen,
    prava: prava ?? this.prava,
    planovac: planovac ?? this.planovac,
    kapacita: kapacita ?? this.kapacita,
  );

  factory UzivatelSpravy.fromJson(Map<String, dynamic> json) => UzivatelSpravy(
    email: json['email'] as String,
    jmeno: json['name'] as String?,
    role: json['role'] == 'admin' ? 'admin' : 'user',
    prihlasen: DateTime.tryParse(json['lastLoginAt'] as String? ?? ''),
    planovac: _prava(json['planner']),
    kapacita: {
      if (json['capacity'] case final Map<String, dynamic> pobocky)
        for (final MapEntry(:key, :value) in pobocky.entries)
          if (value == true) key,
    },
    prava: _prava(json['access']),
  );

  /// `{kód: R/W}` - jen platná práva.
  static Map<String, String> _prava(Object? json) => {
    if (json is Map<String, dynamic>)
      for (final MapEntry(:key, :value) in json.entries)
        if (value == 'R' || value == 'W') key: value as String,
  };
}

class PrehledUzivatelu {
  const PrehledUzivatelu({
    required this.poradace,
    required this.uzivatele,
    this.pobockyPlanu = const [],
  });

  final List<PoradacSpravy> poradace;

  /// Pobočky klempíren - práva v plánovači.
  final List<PobockaPlanu> pobockyPlanu;
  final List<UzivatelSpravy> uzivatele;

  factory PrehledUzivatelu.fromJson(Map<String, dynamic> json) =>
      PrehledUzivatelu(
        poradace: [
          for (final p in json['folders'] as List<dynamic>? ?? const [])
            PoradacSpravy.fromJson(p as Map<String, dynamic>),
        ],
        pobockyPlanu: [
          for (final p in json['plannerBranches'] as List<dynamic>? ?? const [])
            if (p case {'code': final String kod})
              PobockaPlanu(kod: kod, nazev: p['label'] as String? ?? kod),
        ],
        uzivatele: [
          for (final u in json['users'] as List<dynamic>? ?? const [])
            UzivatelSpravy.fromJson(u as Map<String, dynamic>),
        ],
      );
}

/// Shrnutí práv do seznamu, stejné jako na webu: „7× zápis · plánovač
/// Nupaky", „1× zápis, 1× čtení", „Žádný pořadač"; admin „Vše · spravuje
/// uživatele".
String souhrnPrav(
  UzivatelSpravy uzivatel,
  List<PoradacSpravy> poradace, {
  List<PobockaPlanu> pobockyPlanu = const [],
}) {
  if (uzivatel.jeAdmin) return 'Vše · spravuje uživatele';
  final zapis = poradace.where((p) => uzivatel.prava[p.kod] == 'W').length;
  final cteni = poradace.where((p) => uzivatel.prava[p.kod] == 'R').length;
  final prava = zapis + cteni == 0
      ? 'Žádný pořadač'
      : [
          if (zapis > 0) '$zapis× zápis',
          if (cteni > 0) '$cteni× čtení',
        ].join(', ');
  final plan = [
    for (final p in pobockyPlanu)
      if (uzivatel.planovac[p.kod] != null) p.nazev,
  ];
  return plan.isEmpty ? prava : '$prava · plánovač ${plan.join(', ')}';
}

/// Filtr seznamu uživatelů - stejné volby jako na webu.
enum FiltrUzivatelu {
  vse('Všichni'),
  admin('Admini'),
  planovac('S plánovačem'),
  neprihlaseni('Nepřihlášení');

  const FiltrUzivatelu(this.popisek);

  final String popisek;

  bool plati(UzivatelSpravy u) => switch (this) {
    FiltrUzivatelu.vse => true,
    FiltrUzivatelu.admin => u.jeAdmin,
    FiltrUzivatelu.planovac => u.jeAdmin || u.planovac.isNotEmpty,
    FiltrUzivatelu.neprihlaseni => u.prihlasen == null,
  };
}

/// Iniciály do kolečka - „Lang Jaroslav" -> „LJ", e-mail -> první písmeno.
String inicialyUzivatele(String jmeno) {
  final casti = jmeno.trim().split(RegExp(r'\s+')).where((c) => c.isNotEmpty);
  if (casti.isEmpty) return '?';
  final prvni = casti.first[0];
  final posledni = casti.length > 1 ? casti.last[0] : '';
  return (prvni + posledni).toUpperCase();
}
