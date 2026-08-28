import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../domain/entities/kod_vozidla.dart';
import '../domain/entities/vyrez_snimku.dart';

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

  /// Přečte snímek a vrátí, co v něm vypadá jako VIN nebo SPZ.
  ///
  /// Když je zadaný [ramecek] (v souřadnicích náhledu o velikosti
  /// [plochaNahledu]), přečte se **jen jeho obsah**. Kolem štítku bývá
  /// spousta dalšího textu — typové označení, hmotnosti, popisky — a bez
  /// oříznutí by se z něj vybíralo zbytečně. Díky tomu má i velikost
  /// rámečku skutečný vliv na to, co skener najde.
  Future<List<KodVozidla>> precti(
    String cestaKSnimku, {
    Rect? ramecek,
    Size? plochaNahledu,
  }) async {
    var cesta = cestaKSnimku;

    if (ramecek != null && plochaNahledu != null) {
      final oriznuta = await _orizni(cestaKSnimku, ramecek, plochaNahledu);
      // Když se oříznutí nepovede, přečte se radši celý snímek než nic.
      if (oriznuta != null) cesta = oriznuta;
    }

    final text = await _rozpoznavac.processImage(
      InputImage.fromFilePath(cesta),
    );
    return KodyZTextu.najdi(text.text);
  }

  Future<String?> _orizni(String cesta, Rect ramecek, Size plocha) async {
    try {
      final puvodni = File(cesta);
      final data = await puvodni.readAsBytes();

      // Dekódování fotky ve vysokém rozlišení trvá stovky milisekund.
      // Ve vlastním isolate kvůli tomu neposkočí spoušť ani náhled.
      final oriznuta = await Isolate.run(
        () => _oriznBajty(
          data: data,
          plochaSirka: plocha.width,
          plochaVyska: plocha.height,
          ramecek: ramecek,
        ),
      );
      if (oriznuta == null) return null;

      // Vedle původního snímku - fotoaparát tuhle složku už používá,
      // takže je jistě zapisovatelná a systém ji sám uklízí.
      final cil = File(
        '${puvodni.parent.path}/vyrez_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await cil.writeAsBytes(oriznuta);
      return cil.path;
    } on Exception {
      // Oříznutí je vylepšení, ne podmínka - při chybě se čte celý snímek.
      return null;
    }
  }

  Future<void> dispose() => _rozpoznavac.close();
}

/// Ořízne snímek na rámeček. Běží mimo hlavní isolate, proto samostatně.
Uint8List? _oriznBajty({
  required Uint8List data,
  required double plochaSirka,
  required double plochaVyska,
  required Rect ramecek,
}) {
  final nactany = img.decodeImage(data);
  if (nactany == null) return null;

  // Telefon fotku často neotáčí, jen si otočení poznamená do EXIFu.
  // Bez srovnání by souřadnice rámečku ukazovaly úplně jinam.
  final snimek = img.bakeOrientation(nactany);

  // Malá rezerva kolem rámečku. Náhled a výsledná fotka nemají vždy úplně
  // stejný poměr stran, takže výřez může být o kousek posunutý; bez rezervy
  // by se ukrojil první nebo poslední znak. Shora a zdola je větší, protože
  // rámeček je nízký.
  final rezerva = Rect.fromLTRB(
    ramecek.left - ramecek.width * 0.04,
    ramecek.top - ramecek.height * 0.12,
    ramecek.right + ramecek.width * 0.04,
    ramecek.bottom + ramecek.height * 0.12,
  );

  final vyrez = VyrezSnimku.prepocti(
    snimek: Size(snimek.width.toDouble(), snimek.height.toDouble()),
    plocha: Size(plochaSirka, plochaVyska),
    ramecek: rezerva,
  );
  // Z pár pixelů se nic nepřečte - to už je lepší celý snímek.
  if (vyrez.width < 80 || vyrez.height < 40) return null;

  final oriznuty = img.copyCrop(
    snimek,
    x: vyrez.left.round(),
    y: vyrez.top.round(),
    width: vyrez.width.round(),
    height: vyrez.height.round(),
  );

  return img.encodeJpg(oriznuty, quality: 92);
}
