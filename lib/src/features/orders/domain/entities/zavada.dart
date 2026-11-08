import 'dilensky_stav.dart';

/// Závada (úkon) na zakázce z Heliosu. Jen ke čtení - zapisuje ji poradce
/// v Heliosu, dílna ji v aplikaci vidí.
class Zavada {
  const Zavada({required this.id, this.kod, this.nazev, required this.text});

  final String id;

  /// Číslo závady v Heliosu (`reference_subjektu`), pokud je vyplněné.
  final String? kod;

  /// Stručný popis závady (`nazev_subjektu`) - podle něj ji dílna pozná.
  /// `null`, když ho Helios nemá nebo ho server ještě neposílá.
  final String? nazev;

  /// Podrobnosti (poznámka) tak, jak je poradce rozepsal. Může mít víc
  /// řádků.
  final String text;

  /// Název do dílenského stavu - stručný popis, jinak první řádek poznámky.
  String get nazevKroku {
    final radek = text.trim().split('\n').first.trim();
    final vysledek = nazev ?? (radek.isEmpty ? 'Závada' : radek);
    return vysledek.length > 100 ? vysledek.substring(0, 100) : vysledek;
  }

  factory Zavada.fromJson(Map<String, dynamic> json) {
    final kod = (json['code'] as String?)?.trim();
    final nazev = (json['title'] as String?)?.trim();
    return Zavada(
      id: json['id'] as String,
      kod: kod == null || kod.isEmpty ? null : kod,
      nazev: nazev == null || nazev.isEmpty ? null : nazev,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': kod,
    'title': nazev,
    'text': text,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Zavada &&
          other.id == id &&
          other.kod == kod &&
          other.nazev == nazev &&
          other.text == text);

  @override
  int get hashCode => Object.hash(id, kod, nazev, text);
}

/// Úkon zapsaný dílnou mimo Helios - práce navíc nebo něco, co v Heliosu
/// chybí. Zahajuje se a dokončuje stejně jako závada.
class RucniUkon {
  const RucniUkon({
    required this.id,
    required this.nazev,
    this.poznamka,
    this.pridal,
    this.pridano,
  });

  factory RucniUkon.fromJson(Map<String, dynamic> json) {
    final pridano = json['createdAt'] as String?;
    return RucniUkon(
      id: json['id'] as String,
      nazev: json['title'] as String,
      poznamka: json['note'] as String?,
      pridal: json['createdBy'] as String?,
      pridano: pridano == null ? null : DateTime.tryParse(pridano),
    );
  }

  final String id;
  final String nazev;
  final String? poznamka;

  /// Kdo úkon přidal a kdy.
  final String? pridal;
  final DateTime? pridano;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': nazev,
    'note': poznamka,
    'createdBy': pridal,
    'createdAt': pridano?.toIso8601String(),
  };
}

/// Jak je na tom závada podle dílenských stavů.
sealed class StavZavady {
  const StavZavady();
}

class ZavadaCeka extends StavZavady {
  const ZavadaCeka({this.preruseno = false});

  /// Byla zahájená, ale mezitím začal jiný krok.
  final bool preruseno;
}

class ZavadaProbiha extends StavZavady {
  const ZavadaProbiha(this.zaznamId);

  final String zaznamId;
}

class ZavadaHotova extends StavZavady {
  const ZavadaHotova(this.kdy);

  final DateTime kdy;
}

/// Stav závady z historie (nejnovější první). Hotová je jen po Dokončit.
/// Když mezitím začal jiný krok, závada se přerušila a jde zahájit znovu.
/// [rucni] hledá kroky ručního úkonu místo závady z Heliosu.
StavZavady stavZavady(
  String id,
  List<DilenskyStav> historie, {
  bool rucni = false,
}) {
  final posledni = historie
      .where((z) => (rucni ? z.ukonId : z.zavadaId) == id)
      .firstOrNull;
  if (posledni == null) return const ZavadaCeka();
  if (posledni.dokonceno case final kdy?) return ZavadaHotova(kdy);
  final zaznamId = posledni.id;
  return identical(historie.first, posledni) && zaznamId != null
      ? ZavadaProbiha(zaznamId)
      : const ZavadaCeka(preruseno: true);
}
