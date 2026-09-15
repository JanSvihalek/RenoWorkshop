import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/domain/entities/vyrez_snimku.dart';
import '../../../settings/domain/entities/nastaveni.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';

/// Sériové focení do jedné kategorie fotodokumentace.
///
/// Vlastní obrazovka nad kamerou, ne systémový fotoaparát: fotí se jedna
/// fotka za druhou bez znovuotevírání, spoušť je tam, kam si ji technik
/// dal v nastavení, a oprávnění ke kameře řeší stejné místo jako skener.
/// Na Androidu by systémový fotoaparát při neudělení oprávnění spadl.
class SerioveFoceniScreen extends ConsumerStatefulWidget {
  const SerioveFoceniScreen({
    super.key,
    required this.nadpis,
    required this.onFotka,
  });

  /// Kategorie, do které se fotí - ať je vidět, co se má fotit.
  final String nadpis;

  /// Každá fotka hned po pořízení - nahrávat se začne, zatímco se fotí dál.
  final void Function(Uint8List fotka) onFotka;

  @override
  ConsumerState<SerioveFoceniScreen> createState() =>
      _SerioveFoceniScreenState();
}

class _SerioveFoceniScreenState extends ConsumerState<SerioveFoceniScreen> {
  CameraController? _kamera;
  String? _chyba;
  bool _foti = false;
  int _pocet = 0;

  @override
  void initState() {
    super.initState();
    _spust();
  }

  @override
  void dispose() {
    _kamera?.dispose();
    super.dispose();
  }

  Future<void> _spust() async {
    try {
      final kamery = await availableCameras();
      final zadni = kamery.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kamery.first,
      );
      final kamera = CameraController(
        zadni,
        // Dokumentace poškození potřebuje detail - plné rozlišení se před
        // nahráním zmenší na 2000 px v pozadí.
        ResolutionPreset.max,
        enableAudio: false,
      );
      try {
        await kamera.initialize();
      } catch (_) {
        await kamera.dispose();
        rethrow;
      }
      // Bez blesku - odlesky na laku by schovaly škrábance. Jen pokus:
      // tablet bez blesku nastavení odmítne (setFlashModeFailed) a kvůli
      // tomu se focení nesmí zastavit.
      try {
        await kamera.setFlashMode(FlashMode.off);
      } on CameraException {
        // Zařízení bez blesku - není co vypínat.
      }
      if (!mounted) {
        await kamera.dispose();
        return;
      }
      setState(() => _kamera = kamera);
    } on CameraException catch (chyba) {
      if (!mounted) return;
      setState(
        () => _chyba = chyba.code == 'CameraAccessDenied'
            ? 'Aplikace nemá přístup k fotoaparátu. Povolte ho v nastavení.'
            : 'Fotoaparát se nepodařilo spustit (${chyba.code}).',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _chyba = 'Fotoaparát není k dispozici.');
    }
  }

  Future<void> _vyfot() async {
    final kamera = _kamera;
    if (kamera == null || _foti) return;

    setState(() => _foti = true);
    try {
      final snimek = await kamera.takePicture();
      final data = await File(snimek.path).readAsBytes();
      widget.onFotka(data);
      if (mounted) setState(() => _pocet++);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Fotku se nepodařilo pořídit.')),
          );
      }
    } finally {
      if (mounted) setState(() => _foti = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kamera = _kamera;
    final spoust = ref.watch(nastaveniProvider).spoust;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            if (kamera != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox.fromSize(
                  size: VyrezSnimku.velikostNahledu(
                    nahledKamery: kamera.value.previewSize ?? const Size(16, 9),
                    plocha: constraints.biggest,
                  ),
                  child: CameraPreview(kamera),
                ),
              )
            else if (_chyba == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.giant),
                  child: Text(
                    _chyba!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardBody.copyWith(color: Colors.white),
                  ),
                ),
              ),
            SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.xl,
                        Insets.base,
                        Insets.xl,
                        0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.nadpis,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                            ),
                            child: Text(
                              _pocet == 0 ? 'Zavřít' : 'Hotovo ($_pocet)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: switch (spoust) {
                      UmisteniSpouste.vlevo => Alignment.centerLeft,
                      UmisteniSpouste.vpravo => Alignment.centerRight,
                      UmisteniSpouste.dole => Alignment.bottomCenter,
                    },
                    child: Padding(
                      padding: spoust == UmisteniSpouste.dole
                          ? const EdgeInsets.only(bottom: Insets.giant)
                          : const EdgeInsets.symmetric(horizontal: Insets.xl),
                      child: _Spoust(
                        foti: _foti,
                        onTap: kamera == null ? null : _vyfot,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spoust extends StatelessWidget {
  const _Spoust({required this.foti, required this.onTap});

  final bool foti;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vyfotit',
      child: GestureDetector(
        onTap: foti ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Krátké zhasnutí při focení - technik pozná, že fotka je.
            color: Colors.white.withValues(
              alpha: onTap == null ? 0.3 : (foti ? 0.5 : 1),
            ),
            border: Border.all(color: Colors.white54, width: 4),
          ),
        ),
      ),
    );
  }
}
