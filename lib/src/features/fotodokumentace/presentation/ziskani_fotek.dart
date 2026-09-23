import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'screens/seriove_foceni_screen.dart';

/// Odkud se berou fotky do fotodokumentace - galerie telefonu a sériové
/// focení. Vlastní rozhraní, ať testy nepotřebují fotoaparát ani galerii.
abstract interface class ZiskaniFotek {
  /// Vybrané fotky z galerie; prázdný seznam, když uživatel nic nevybral.
  Future<List<Uint8List>> zGalerie(BuildContext context);

  /// Jedna fotka z fotoaparátu, nebo `null`, když uživatel focení zrušil.
  /// Pro místo vozu u dílenského stavu - sériové focení by tam bylo moc.
  Future<Uint8List?> jednaFotka(BuildContext context);

  /// Sériové focení. Každá pořízená fotka jde hned do [onFotka], ať se
  /// začne nahrávat, zatímco technik fotí dál.
  Future<void> foceni(
    BuildContext context, {
    required String nadpis,
    required void Function(Uint8List fotka) onFotka,
  });
}

final ziskaniFotekProvider = Provider<ZiskaniFotek>((ref) => _ZiskaniFotek());

class _ZiskaniFotek implements ZiskaniFotek {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<List<Uint8List>> zGalerie(BuildContext context) async {
    try {
      // Rozměry a kvalita už tady: na iOS tím galerie převede HEIC na JPEG
      // a nepřenáší se plné rozlišení. Konečnou úpravu stejně dělá
      // pripravFotku.
      final soubory = await _picker.pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
      return [for (final soubor in soubory) await soubor.readAsBytes()];
    } on PlatformException catch (chyba) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chyba.code == 'photo_access_denied'
                  ? 'Aplikace nemá přístup ke galerii. Povolte ho v nastavení.'
                  : 'Galerii se nepodařilo otevřít.',
            ),
          ),
        );
      }
      return const [];
    }
  }

  @override
  Future<Uint8List?> jednaFotka(BuildContext context) async {
    try {
      final snimek = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
      return snimek == null ? null : await snimek.readAsBytes();
    } on PlatformException catch (chyba) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chyba.code == 'camera_access_denied'
                  ? 'Aplikace nemá přístup k fotoaparátu. Povolte ho '
                        'v nastavení.'
                  : 'Fotoaparát se nepodařilo otevřít.',
            ),
          ),
        );
      }
      return null;
    }
  }

  @override
  Future<void> foceni(
    BuildContext context, {
    required String nadpis,
    required void Function(Uint8List fotka) onFotka,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SerioveFoceniScreen(nadpis: nadpis, onFotka: onFotka),
      ),
    );
  }
}
