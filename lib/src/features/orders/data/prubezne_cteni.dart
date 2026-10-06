import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/entities/kod_vozidla.dart';

// Průběžné čtení SPZ z obrazu kamery - bez spouště.
//
// Kamera posílá snímky náhledu a skener z nich čte jen to, co je
// v rámečku. Hledá se teprve, když se stejná SPZ přečte víckrát po sobě
// ([PotvrzeniSpz]) - jedno špatné přečtení tak hledání nespustí.
//
// ML Kit bere snímky z kamery bez převodu jen v určitém formátu: na
// Androidu NV21, na iOS BGRA. Kamera se proto musí spustit s
// [formatProCteni]. Ověřené zatím jen podle dokumentace ML Kitu, ne na
// zařízeních - když se snímek převést nepodaří, čtení se tiše vynechá
// a zbývá spoušť.

/// Formát snímků pro [CameraController.imageFormatGroup].
ImageFormatGroup get formatProCteni =>
    Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21;

const _otoceniZarizeni = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// O kolik stupňů je snímek ze snímače otočený proti tomu, jak ho vidí
/// člověk. `null` = nejde určit, snímek se nečte.
///
/// Na Androidu se od otočení snímače odečte otočení zařízení (u přední
/// kamery přičte - je zrcadlená), postup podle příkladu
/// k google_mlkit_commons.
///
/// Na iOS plugin kamery snímky otáčí podle zařízení sám - na iPadu na
/// šířku chodí 1280×720. Příklad ML Kitu počítá s appkou zamčenou na
/// výšku a otočení snímače by přičetl podruhé (tak se to 6. 10. 2026
/// ukázalo na iPadu). Proto se rozhoduje podle tvaru: [snimek] stejně
/// orientovaný jako [plocha] je už otočený správně.
int? otoceniSnimku({
  required bool ios,
  required int snimac,
  required DeviceOrientation zarizeni,
  required Size snimek,
  required Size plocha,
  bool predni = false,
}) {
  if (ios) {
    final stejnyTvar =
        (snimek.width >= snimek.height) == (plocha.width >= plocha.height);
    return stejnyTvar ? 0 : snimac % 360;
  }
  final kompenzace = _otoceniZarizeni[zarizeni];
  if (kompenzace == null) return null;
  return predni
      ? (snimac + kompenzace) % 360
      : (snimac - kompenzace + 360) % 360;
}

/// Rozměr snímku po otočení do polohy, jak ho vidí člověk. V něm ML Kit
/// vrací polohu přečteného textu.
Size vzprimenaVelikost(Size snimek, int otoceni) =>
    otoceni == 90 || otoceni == 270 ? snimek.flipped : snimek;

/// Snímek z kamery jako vstup pro ML Kit. `null`, když je v jiném
/// formátu, než ML Kit bez převodu umí.
InputImage? obrazProCteni(CameraImage snimek, int otoceni) {
  final rotace = InputImageRotationValue.fromRawValue(otoceni);
  final format = InputImageFormatValue.fromRawValue(snimek.format.raw);
  if (rotace == null || format == null) return null;
  final ocekavany = Platform.isIOS
      ? InputImageFormat.bgra8888
      : InputImageFormat.nv21;
  if (format != ocekavany || snimek.planes.length != 1) return null;

  final rovina = snimek.planes.single;
  return InputImage.fromBytes(
    bytes: rovina.bytes,
    metadata: InputImageMetadata(
      size: Size(snimek.width.toDouble(), snimek.height.toDouble()),
      rotation: rotace,
      format: format,
      bytesPerRow: rovina.bytesPerRow,
    ),
  );
}

/// Oblast rámečku s rezervou. Snímky pro čtení mívají jiný poměr stran
/// než náhled (CameraX je posílá 4:3, náhled bývá 16:9), takže přepočet
/// rámečku nesedí na pixel - bez rezervy by SPZ u okraje vypadla.
Rect sRezervou(Rect oblast) => Rect.fromLTRB(
  oblast.left - oblast.width * 0.15,
  oblast.top - oblast.height * 0.5,
  oblast.right + oblast.width * 0.15,
  oblast.bottom + oblast.height * 0.5,
);

/// Text řádků, jejichž střed leží v [oblast] - jen to, co je v rámečku.
/// Kolem SPZ bývá další text (sousední vůz, nápisy na stěně).
String textVOblasti(Iterable<(Rect, String)> radky, Rect oblast) => [
  for (final (poloha, text) in radky)
    if (oblast.contains(poloha.center)) text,
].join('\n');

/// Hlídá, aby se SPZ přečetla stejně víckrát po sobě, než se podle ní
/// hledá.
///
/// Rozpoznávání z rozmazaného snímku občas splete znak (8 a B, 0 a D).
/// U spouště to vyřeší člověk výběrem, tady nikdo nevybírá - proto
/// potvrzení. Snímek bez SPZ (rozmazaný, mimo rámeček) počítání
/// nepřeruší, jiná SPZ ho začne znovu.
class PotvrzeniSpz {
  PotvrzeniSpz({this.potreba = 2});

  /// Kolikrát po sobě musí vyjít stejná SPZ.
  final int potreba;

  String? _posledni;
  var _pocet = 0;

  /// Přidá kódy z dalšího snímku. Vrátí SPZ, jakmile je potvrzená.
  ///
  /// Bere první nalezenou SPZ - spojená slova (značka z tabulky bývá
  /// rozdělená mezerou) mají v [KodyZTextu.najdi] přednost.
  KodVozidla? pridej(List<KodVozidla> kody) {
    final spz = kody.where((k) => k.druh == DruhKodu.spz).firstOrNull;
    if (spz == null) return null;

    if (spz.hodnota == _posledni) {
      _pocet++;
    } else {
      _posledni = spz.hodnota;
      _pocet = 1;
    }
    return _pocet >= potreba ? spz : null;
  }

  void vynuluj() {
    _posledni = null;
    _pocet = 0;
  }
}
