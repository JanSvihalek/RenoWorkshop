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

  /// Poslední pořízená fotka - náhled v rohu, ať technik vidí, že fotka je.
  /// Drží se jen ta jedna, deset fotek v paměti by telefon zbytečně zatížilo.
  Uint8List? _posledni;

  FlashMode _blesk = FlashMode.off;

  /// Tablet blesk nemá; pozná se to až podle odmítnutí a tlačítko pak zmizí.
  bool _maBlesk = true;

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
      // Začíná se bez blesku - odlesky na laku schovají škrábance. Jen
      // pokus: tablet bez blesku nastavení odmítne (setFlashModeFailed)
      // a kvůli tomu se focení nesmí zastavit.
      try {
        await kamera.setFlashMode(FlashMode.off);
      } on CameraException {
        if (mounted) setState(() => _maBlesk = false);
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

  /// Přepíná vypnuto → automaticky → zapnuto. Když zařízení blesk nemá,
  /// tlačítko po prvním pokusu zmizí.
  Future<void> _prepniBlesk() async {
    final kamera = _kamera;
    if (kamera == null) return;
    final novy = switch (_blesk) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await kamera.setFlashMode(novy);
      if (mounted) setState(() => _blesk = novy);
    } on CameraException {
      if (!mounted) return;
      setState(() => _maBlesk = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Tohle zařízení blesk nemá.')),
        );
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
      if (mounted) {
        setState(() {
          _pocet++;
          _posledni = data;
        });
      }
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
            // Tmavý přechod pod horní lištou - na světlém náhledu (bílé
            // auto, zeď v hale) by bílý text i tlačítka zanikly.
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
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
                          // Šipka zpět i tlačítko Hotovo dělají totéž -
                          // z focení se odchází kamkoli z obou stran.
                          IconButton(
                            key: const Key('foceni-zpet'),
                            tooltip: 'Zpět',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.nadpis,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_maBlesk)
                            IconButton(
                              key: const Key('foceni-blesk'),
                              tooltip: switch (_blesk) {
                                FlashMode.off => 'Blesk vypnutý',
                                FlashMode.auto => 'Blesk automaticky',
                                _ => 'Blesk zapnutý',
                              },
                              onPressed: kamera == null ? null : _prepniBlesk,
                              icon: Icon(
                                switch (_blesk) {
                                  FlashMode.off => Icons.flash_off_rounded,
                                  FlashMode.auto => Icons.flash_auto_rounded,
                                  _ => Icons.flash_on_rounded,
                                },
                                color: _blesk == FlashMode.off
                                    ? Colors.white
                                    : AppColors.accent,
                              ),
                            ),
                          const SizedBox(width: Insets.sm),
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
                  if (_posledni case final fotka?)
                    Align(
                      // Na opačné straně než spoušť, ať ji náhled nekryje.
                      alignment: spoust == UmisteniSpouste.vlevo
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.xl),
                        child: _NahledPosledni(fotka: fotka, pocet: _pocet),
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

/// Poslední vyfocená fotka a kolik jich v této kategorii přibylo.
class _NahledPosledni extends StatelessWidget {
  const _NahledPosledni({required this.fotka, required this.pocet});

  final Uint8List fotka;
  final int pocet;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('foceni-nahled'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(Radii.input),
        border: Border.all(color: Colors.white70, width: 2),
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.input - 3),
            child: Image.memory(
              fotka,
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              // Náhled se dekóduje zmenšený - fotka z telefonu má i deset
              // megapixelů a v plné velikosti by ukrojila z paměti.
              cacheWidth: 180,
              gaplessPlayback: true,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Text(
              '$pocet',
              style: AppTextStyles.chip.copyWith(color: Colors.white),
            ),
          ),
        ],
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
        key: const Key('foceni-spoust'),
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
