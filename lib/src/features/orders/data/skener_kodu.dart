import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/entities/kod_vozidla.dart';

/// Přečtení VINu nebo SPZ ze snímku.
///
/// Rozpoznávání běží **v telefonu**, ne v cloudu: funguje i bez signálu
/// a fotka nikam neodchází.
///
/// Vrací návrhy, ne jistotu. Poslední slovo má člověk, který si z nabídky
/// vybere — štítek pod kapotou bývá špinavý a slepé spolehnutí na strojové
/// čtení by vedlo k hledání nesmyslů.
class SkenerKodu {
  SkenerKodu({TextRecognizer? rozpoznavac})
    : _rozpoznavac = rozpoznavac ?? TextRecognizer();

  final TextRecognizer _rozpoznavac;

  /// Přečte snímek pořízený fotoaparátem a vrátí, co v něm vypadá
  /// jako VIN nebo SPZ.
  Future<List<KodVozidla>> precti(String cestaKSnimku) async {
    final text = await _rozpoznavac.processImage(
      InputImage.fromFilePath(cestaKSnimku),
    );
    return KodyZTextu.najdi(text.text);
  }

  Future<void> dispose() => _rozpoznavac.close();
}
