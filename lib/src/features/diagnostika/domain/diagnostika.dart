import 'package:flutter/foundation.dart';

/// Diagnostický protokol BMW ISPI ze serveru pobočky
/// (`GET /orders/{id}/diagnostics`). Ke zakázce ho služba páruje podle VIN
/// a období zakázky.
@immutable
class ProtokolDiagnostiky {
  const ProtokolDiagnostiky({
    required this.id,
    required this.cas,
    required this.zdroj,
    required this.hlavniId,
    required this.hlavniNazev,
  });

  final String id;

  /// Kdy se vůz napíchl na diagnostiku (místní čas dílny).
  final DateTime cas;

  /// Server pobočky („Brno").
  final String zdroj;

  /// Hlavní PDF - finální report.
  final String hlavniId;
  final String hlavniNazev;

  factory ProtokolDiagnostiky.fromJson(Map<String, dynamic> json) {
    final hlavni = json['mainFile'] as Map<String, dynamic>? ?? const {};
    return ProtokolDiagnostiky(
      id: '${json['id']}',
      cas: DateTime.parse(json['at'] as String),
      zdroj: json['source'] as String? ?? '',
      hlavniId: hlavni['id'] as String? ?? '',
      hlavniNazev: hlavni['name'] as String? ?? 'protokol.pdf',
    );
  }
}

/// Soubor protokolu - hlavní PDF, nebo podrobný protokol ze složky
/// ISPA-Data / ISTA-Data.
@immutable
class SouborDiagnostiky {
  const SouborDiagnostiky({
    required this.id,
    required this.nazev,
    this.slozka,
    this.velikost = 0,
    this.hlavni = false,
  });

  final String id;
  final String nazev;

  /// Podsložka (`ISTA-Data`); `null` = kořen protokolu.
  final String? slozka;
  final int velikost;
  final bool hlavni;

  factory SouborDiagnostiky.fromJson(Map<String, dynamic> json) =>
      SouborDiagnostiky(
        id: json['id'] as String,
        nazev: json['name'] as String,
        slozka: json['folder'] as String?,
        velikost: (json['size'] as num?)?.toInt() ?? 0,
        hlavni: json['main'] as bool? ?? false,
      );
}

/// „196 kB", „2,3 MB".
String velikostSouboru(int bajty) => bajty >= 1024 * 1024
    ? '${(bajty / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB'
    : '${(bajty / 1024).round().clamp(1, 1023)} kB';
