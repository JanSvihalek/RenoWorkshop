import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../domain/entities/fotka.dart';

/// Zdroj fotodokumentace. Plní ho tentýž zdroj jako zakázky - fotky vrací
/// a přijímá stejná služba na RENDCAPPu.
abstract interface class FotkyDataSource {
  /// `GET /orders/{id}/photos` - fotky zakázky, nejnovější první.
  Future<List<Fotka>> fotkyZakazky(String orderId);

  /// `POST /orders/{id}/photos?category=...` - JPEG tělo.
  Future<Fotka> nahrajFotku(
    String orderId,
    KategorieFotky kategorie,
    Uint8List jpeg,
  );

  /// `GET /photos/{id}` - bajty fotky. Přes službu a s přihlášením, ne
  /// přímou adresou: telefon na sdílenou složku nesahá.
  Future<Uint8List> stahniFotku(String id);

  /// `DELETE /photos/{id}`.
  Future<void> smazFotku(String id);
}

/// Nejdelší strana fotky po zmenšení. Na přečtení VINu i posouzení
/// škrábance stačí, a fotka má kolem půl megabajtu místo deseti.
const nejdelsiStranaFotky = 2000;

/// Fotka z fotoaparátu nebo galerie připravená k nahrání: srovnaná podle
/// EXIFu, zmenšená a jako JPEG. `null`, když se obrázek nedá přečíst.
///
/// Srovnání otočení je nutné - telefon fotku často neotočí, jen si otočení
/// poznamená, a kolega na počítači by pak na sdílené složce viděl VIN
/// vzhůru nohama. Galerie navíc umí vrátit PNG; server přijímá jen JPEG.
///
/// Běží mimo hlavní isolate (volá se přes `Isolate.run`), dekódování velké
/// fotky by jinak zadrhlo obrazovku.
Uint8List? pripravFotku(Uint8List data) {
  final img.Image? nactena;
  try {
    nactena = img.decodeImage(data);
  } catch (_) {
    // Knihovna na poškozených datech nevrací null, ale vyhodí výjimku.
    return null;
  }
  if (nactena == null) return null;

  var fotka = img.bakeOrientation(nactena);
  final delsi = fotka.width > fotka.height ? fotka.width : fotka.height;
  if (delsi > nejdelsiStranaFotky) {
    fotka = fotka.width >= fotka.height
        ? img.copyResize(fotka, width: nejdelsiStranaFotky)
        : img.copyResize(fotka, height: nejdelsiStranaFotky);
  }
  return img.encodeJpg(fotka, quality: 85);
}
