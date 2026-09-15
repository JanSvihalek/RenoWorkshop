import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../domain/entities/fotka.dart';

/// Záloha fotek z fotoaparátu do galerie telefonu.
///
/// Pojistka pro halu bez signálu: fotka je v telefonu hned po vyfocení,
/// nezávisle na tom, jestli se nahraje. Kdyby se nenahrála a technik ji
/// zahodil nebo aplikaci zavřel, jde ji později přidat přes „Přidat
/// z galerie". Vlastní rozhraní, ať testy nepotřebují galerii.
abstract interface class UlozeniDoZarizeni {
  /// Požádá o přístup ke galerii. `false`, když ho technik nepovolil.
  Future<bool> pozadejPristup();

  /// Uloží fotku do alba [albumFotek]. Při chybě vyhodí
  /// [UlozeniDoZarizeniException] se srozumitelnou zprávou.
  Future<void> uloz(Uint8List jpeg, {required String nazev});
}

class UlozeniDoZarizeniException implements Exception {
  const UlozeniDoZarizeniException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Album v galerii - fotky zakázek se nepletou mezi soukromé.
const albumFotek = 'RenoWorkshop';

/// Jméno fotky v galerii: zakázka, kategorie a čas, ať jde podle něj
/// dohledat, ke které zakázce patří. Milisekundy proto, že sériové focení
/// udělá víc fotek za vteřinu.
String nazevFotkyVZarizeni(
  String orderId,
  KategorieFotky kategorie,
  DateTime cas,
) {
  String dvoj(int n) => n.toString().padLeft(2, '0');
  final razitko =
      '${cas.year}${dvoj(cas.month)}${dvoj(cas.day)}'
      '-${dvoj(cas.hour)}${dvoj(cas.minute)}${dvoj(cas.second)}'
      '-${cas.millisecond.toString().padLeft(3, '0')}';
  final zakazka = orderId.replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '-');
  return '${zakazka}_${kategorie.klic}_$razitko';
}

final ulozeniDoZarizeniProvider = Provider<UlozeniDoZarizeni>(
  (ref) => _GalerieTelefonu(),
);

class _GalerieTelefonu implements UlozeniDoZarizeni {
  @override
  Future<bool> pozadejPristup() async {
    try {
      return await Gal.hasAccess(toAlbum: true) ||
          await Gal.requestAccess(toAlbum: true);
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> uloz(Uint8List jpeg, {required String nazev}) async {
    try {
      await Gal.putImageBytes(jpeg, album: albumFotek, name: nazev);
    } on GalException catch (chyba) {
      throw UlozeniDoZarizeniException(switch (chyba.type) {
        GalExceptionType.accessDenied =>
          'Fotku nejde uložit do telefonu - aplikace nemá přístup k fotkám.',
        GalExceptionType.notEnoughSpace =>
          'Fotku nejde uložit do telefonu - není v něm místo.',
        _ => 'Fotku se nepodařilo uložit do telefonu.',
      });
    } on PlatformException {
      throw const UlozeniDoZarizeniException(
        'Fotku se nepodařilo uložit do telefonu.',
      );
    }
  }
}
