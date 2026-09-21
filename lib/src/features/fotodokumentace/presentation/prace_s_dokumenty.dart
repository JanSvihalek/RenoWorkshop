import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/entities/dokument.dart';

/// Soubor vybraný v zařízení. Bajty se čtou až při nahrávání - soubor
/// přes limit se tak vůbec nenačte do paměti.
class VybranySoubor {
  const VybranySoubor({
    required this.nazev,
    required this.velikost,
    required this.nacti,
  });

  final String nazev;
  final int velikost;
  final Future<Uint8List> Function() nacti;
}

class PraceSDokumentyException implements Exception {
  const PraceSDokumentyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Výběr dokumentu v zařízení (na iPadu aplikace Soubory, na Androidu
/// správce souborů) a jeho zobrazení. Vlastní rozhraní, ať testy
/// nepotřebují systémová okna.
abstract interface class PraceSDokumenty {
  /// Vybrané soubory; prázdný seznam, když uživatel nic nevybral.
  Future<List<VybranySoubor>> vyber();

  /// Ukáže dokument. Na iPadu náhledem přímo v aplikaci, na Androidu
  /// v aplikaci, kterou má zařízení pro daný typ (prohlížeč PDF...).
  Future<void> otevri(String nazev, Uint8List data);
}

final praceSDokumentyProvider = Provider<PraceSDokumenty>(
  (ref) => _PraceSDokumenty(),
);

class _PraceSDokumenty implements PraceSDokumenty {
  @override
  Future<List<VybranySoubor>> vyber() async {
    try {
      final soubory = await FilePicker.pickFiles(
        dialogTitle: 'Vyberte dokument',
        type: FileType.custom,
        allowedExtensions: priponyDokumentu,
      );
      return [
        for (final soubor in soubory)
          VybranySoubor(
            nazev: soubor.name,
            velikost: await soubor.length() ?? 0,
            nacti: soubor.readAsBytes,
          ),
      ];
    } on PlatformException catch (chyba) {
      throw PraceSDokumentyException(
        'Soubory se nepodařilo otevřít: ${chyba.message ?? chyba.code}',
      );
    }
  }

  @override
  Future<void> otevri(String nazev, Uint8List data) async {
    // Do mezipaměti aplikace: systém ji smí promazat a do galerie ani
    // Souborů se nic neukládá. Každý dokument ve vlastní složce, ať se
    // stejně pojmenované soubory ze dvou zakázek nepřepíšou při otevírání.
    final docasna = await getTemporaryDirectory();
    final slozka = await Directory(
      '${docasna.path}/dokumenty/${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    final soubor = File('${slozka.path}/$nazev');
    await soubor.writeAsBytes(data, flush: true);

    final vysledek = await OpenFilex.open(soubor.path);
    switch (vysledek.type) {
      case ResultType.done:
        return;
      case ResultType.noAppToOpen:
        throw const PraceSDokumentyException(
          'V zařízení není aplikace, která tento typ souboru otevře.',
        );
      case ResultType.fileNotFound:
      case ResultType.permissionDenied:
      case ResultType.error:
        throw PraceSDokumentyException(
          'Dokument se nepodařilo otevřít: ${vysledek.message}',
        );
    }
  }
}
