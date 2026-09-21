import 'package:flutter/material.dart';

/// Kategorie fotodokumentace zakázky.
///
/// Klíč se posílá na server a určuje podsložku ve sdílené složce
/// (`Foto-doc\<pobočka>\<zakázka>\<kategorie>`). Pořadí je pořadí karet
/// na obrazovce - odpovídá tomu, jak se vůz při příjmu obchází.
enum KategorieFotky {
  exterier('exterier', 'Exteriér (dokola vozu)', Icons.directions_car_rounded),
  poskozeni('poskozeni', 'Zjištěná poškození', Icons.car_crash_rounded),
  kola('kola', 'Disky a kola', Icons.tire_repair_rounded),
  stk('stk', 'Nálepka STK', Icons.event_available_rounded),
  interier('interier', 'Interiér vozu', Icons.airline_seat_recline_normal),
  tachometr('tachometr', 'Tachometr a přístrojová deska', Icons.speed_rounded),
  vin('vin', 'VIN kód', Icons.pin_rounded),
  // Ikona složky: kromě fotek sem patří PDF a všechno ze složky zakázky,
  // co neleží v ostatních kategoriích.
  ostatni('ostatni', 'Ostatní dokumentace', Icons.folder_rounded);

  const KategorieFotky(this.klic, this.nazev, this.ikona);

  /// Klíč pro API.
  final String klic;
  final String nazev;
  final IconData ikona;

  /// Název bez upřesnění v závorce - do souhrnu v detailu zakázky.
  String get kratkyNazev => nazev.split(' (').first;

  static KategorieFotky? zKlice(String? klic) {
    for (final kategorie in values) {
      if (kategorie.klic == klic) return kategorie;
    }
    return null;
  }
}

/// „1 fotka", „3 fotky", „5 fotek".
String pocetFotek(int pocet) => switch (pocet) {
  1 => '1 fotka',
  >= 2 && <= 4 => '$pocet fotky',
  _ => '$pocet fotek',
};

/// Fotka nahraná k zakázce.
@immutable
class Fotka {
  const Fotka({
    required this.id,
    required this.kategorie,
    required this.nahranoAt,
    this.nahralKdo,
  });

  final String id;
  final KategorieFotky kategorie;
  final DateTime nahranoAt;
  final String? nahralKdo;

  /// Z odpovědi API. Neznámá kategorie (novější server) spadne do Ostatní,
  /// ať fotka nezmizí.
  factory Fotka.fromJson(Map<String, dynamic> json) => Fotka(
    id: json['id'] as String,
    kategorie:
        KategorieFotky.zKlice(json['category'] as String?) ??
        KategorieFotky.ostatni,
    nahranoAt:
        DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
        DateTime.now(),
    nahralKdo: json['uploadedBy'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Fotka && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
