import 'package:flutter/material.dart';

/// Dokument zakázky - PDF, sken, tabulka. Leží ve složce zakázky ve
/// Foto-doc; nahraný z aplikace, nebo tam kolega vložil soubor ručně.
@immutable
class Dokument {
  const Dokument({
    required this.id,
    required this.nazev,
    required this.velikost,
    required this.zmenenoAt,
    this.nahranyZAplikace = true,
  });

  /// Umístění souboru zakódované serverem - posílá se zpět při stažení.
  final String id;
  final String nazev;
  final int velikost;
  final DateTime zmenenoAt;

  /// `false` = soubor vložený ručně do složky zakázky.
  final bool nahranyZAplikace;

  factory Dokument.fromJson(Map<String, dynamic> json) => Dokument(
    id: json['id'] as String,
    nazev: json['name'] as String,
    velikost: (json['size'] as num?)?.toInt() ?? 0,
    zmenenoAt:
        DateTime.tryParse(json['modifiedAt'] as String? ?? '') ??
        DateTime.now(),
    nahranyZAplikace: json['uploaded'] as bool? ?? true,
  );

  String get pripona {
    final tecka = nazev.lastIndexOf('.');
    return tecka < 0 ? '' : nazev.substring(tecka + 1).toLowerCase();
  }

  IconData get ikona => switch (pripona) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'jpg' || 'jpeg' || 'png' || 'heic' => Icons.image_rounded,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
    'doc' || 'docx' || 'txt' => Icons.description_rounded,
    _ => Icons.insert_drive_file_rounded,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Dokument && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Přípony, které jde nahrát z aplikace. Musí odpovídat serveru
/// (`POVOLENE_PRIPONY` v RenoWorkshopApi/src/domain/dokumenty.ts).
const priponyDokumentu = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'heic',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'txt',
  'csv',
];

/// Strop serveru pro jeden dokument.
const maxVelikostDokumentu = 25 * 1024 * 1024;

/// „820 kB", „2,4 MB".
String velikostSouboru(int bajty) {
  if (bajty < 1024 * 1024) {
    return '${(bajty / 1024).ceil()} kB';
  }
  final mb = bajty / (1024 * 1024);
  return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// „1 dokument", „3 dokumenty", „5 dokumentů".
String pocetDokumentu(int pocet) => switch (pocet) {
  1 => '1 dokument',
  >= 2 && <= 4 => '$pocet dokumenty',
  _ => '$pocet dokumentů',
};
