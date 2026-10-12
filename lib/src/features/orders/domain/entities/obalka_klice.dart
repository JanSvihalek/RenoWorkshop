/// Obálka s klíčem od vozu - náhrada desek s kapsičkou, ve kterých dřív
/// putoval zakázkový list i s klíčem na dílnu.
///
/// Každá obálka má natrvalo štítek s kódem a QR kódem (`KBSL-023`). Při
/// příjmu technik vloží klíč do volné obálky a naskenuje ji - obálka tím
/// patří zakázce. Uvolní se, když zakázka skončí v Heliosu, nebo ručně.
class ObalkaKlice {
  const ObalkaKlice({
    required this.kod,
    required this.nazevPobocky,
    this.prirazeno,
    this.prirazilKdo,
  });

  /// `KBSL-023`.
  final String kod;

  /// `Brno Slatina`.
  final String nazevPobocky;
  final DateTime? prirazeno;
  final String? prirazilKdo;

  /// Číslo bez předpony - podle něj obálka visí na háčku.
  String get cislo => kod.split('-').last;

  factory ObalkaKlice.fromJson(Map<String, dynamic> json) => ObalkaKlice(
    kod: json['code'] as String,
    nazevPobocky:
        json['branchName'] as String? ?? json['branch'] as String? ?? '',
    prirazeno: DateTime.tryParse(json['assignedAt'] as String? ?? ''),
    prirazilKdo: json['assignedBy'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'code': kod,
    'branch': kod.length >= 4 ? kod.substring(1, 4) : null,
    'branchName': nazevPobocky,
    'assignedAt': prirazeno?.toIso8601String().substring(0, 19),
    'assignedBy': prirazilKdo,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ObalkaKlice &&
          other.kod == kod &&
          other.prirazeno == prirazeno);

  @override
  int get hashCode => Object.hash(kod, prirazeno);
}

/// Kódy chyb ze serveru, které jsou otázkou, ne chybou: obálka patří jiné
/// rozdělané zakázce, nebo je z jiné pobočky. Po potvrzení se pošle znovu
/// s `force`.
const otazkyObalky = {'envelope_in_use', 'envelope_other_branch'};

/// Pobočky, pro které jsou obálky - zkratka je v kódu obálky.
const pobockyObalek = {
  'BSL': 'Brno Slatina',
  'CLI': 'Čestlice',
  'PKC': 'Kongresové centrum',
  'CSK': 'Česká',
  'PBU': 'Bubeneč',
  'NUP': 'Nupaky',
};

final _tvarKodu = RegExp(r'^K([A-Z]{3})-?(\d{1,3})$');

/// Kód obálky v jednotném tvaru (`KBSL-023`), nebo `null`, když to obálka
/// není. Snese malá písmena, mezery a chybějící pomlčku či nuly - stejně
/// jako služba (domain/obalky.ts v RenoWorkshopApi).
String? kodObalky(String text) {
  final shoda = _tvarKodu.firstMatch(
    text.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
  );
  if (shoda == null) return null;
  final pobocka = shoda.group(1)!;
  final cislo = shoda.group(2)!;
  if (!pobockyObalek.containsKey(pobocka) || int.parse(cislo) == 0) {
    return null;
  }
  return 'K$pobocka-${cislo.padLeft(3, '0')}';
}

/// Komu naskenovaná obálka patří - odpověď na `GET /envelopes/:code`.
class NalezenaObalka {
  const NalezenaObalka({
    required this.kod,
    this.zakazkaId,
    this.spz,
    this.aktivni = true,
  });

  final String kod;

  /// Rozdělaná zakázka, které obálka patří. `null` = obálka je volná.
  final String? zakazkaId;
  final String? spz;

  /// Vyřazená obálka (ztracená, zničená).
  final bool aktivni;

  factory NalezenaObalka.fromJson(Map<String, dynamic> json) {
    final zakazka = json['order'] as Map<String, dynamic>?;
    return NalezenaObalka(
      kod: json['code'] as String,
      zakazkaId: zakazka?['id'] as String?,
      spz: zakazka?['licensePlate'] as String?,
      aktivni: json['active'] as bool? ?? true,
    );
  }
}
