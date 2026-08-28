import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/entities/kod_vozidla.dart';

/// Načtení VINu nebo SPZ fotoaparátem.
///
/// Rozpoznávání běží **v telefonu**, ne v cloudu: funguje i bez signálu
/// a fotka nikam neodchází. Vrací návrhy, ze kterých si člověk vybere -
/// štítek pod kapotou bývá špinavý a slepé spolehnutí na strojové čtení
/// by vedlo k hledání nesmyslů.
///
/// Používá systémový fotoaparát (`image_picker`), ne vlastní náhled.
/// Je to o krok navíc, ale chová se to na obou platformách stejně
/// a nemusí se řešit otáčení obrazu ani oprávnění ke kameře zvlášť.
class SkenerKodu {
  SkenerKodu({ImagePicker? picker, TextRecognizer? rozpoznavac})
    : _picker = picker ?? ImagePicker(),
      _rozpoznavac = rozpoznavac ?? TextRecognizer();

  final ImagePicker _picker;
  final TextRecognizer _rozpoznavac;

  /// Vyfotí štítek a vrátí, co v něm vypadá jako VIN nebo SPZ.
  ///
  /// Prázdný seznam znamená, že se nic nenašlo. `null` znamená, že
  /// uživatel focení zrušil - to není chyba a nemá se hlásit.
  Future<List<KodVozidla>?> nactiZFotoaparatu() async {
    final snimek = await _picker.pickImage(
      source: ImageSource.camera,
      // Štítky bývají malým písmem, takže se rozlišení nesnižuje víc,
      // než je nutné; menší obrázek by čtení znatelně zhoršil.
      maxWidth: 2400,
      imageQuality: 90,
    );
    if (snimek == null) return null;

    final text = await _rozpoznavac.processImage(
      InputImage.fromFilePath(snimek.path),
    );

    return KodyZTextu.najdi(text.text);
  }

  Future<void> dispose() => _rozpoznavac.close();
}
