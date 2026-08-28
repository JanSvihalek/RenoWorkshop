import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/kod_vozidla.dart';
import '../controllers/orders_providers.dart';

/// Načtení VINu nebo SPZ fotoaparátem.
///
/// Vlastní náhled s rámečkem, ne systémový fotoaparát: mechanik vidí, kam
/// má mířit, a je to o dvě klepnutí míň. V rámečku je i světlo, protože
/// štítek s VINem bývá na tmavém místě pod kapotou.
///
/// Snímek se pořizuje spouští, ne průběžným čtením obrazu. Průběžné
/// rozpoznávání vyžaduje převod snímků z kamery, který se chová jinak na
/// Androidu a jinak na iOS - až se to ověří na zařízeních, dá se doplnit,
/// aniž by se cokoli měnilo okolo.
class SkenerScreen extends ConsumerStatefulWidget {
  const SkenerScreen({
    super.key,
    required this.onNalezeno,
    required this.onBack,
  });

  /// Vrací vybraný kód. Prázdné pole znamená, že se nic nenašlo.
  final void Function(KodVozidla kod) onNalezeno;
  final VoidCallback onBack;

  @override
  ConsumerState<SkenerScreen> createState() => _SkenerScreenState();
}

class _SkenerScreenState extends ConsumerState<SkenerScreen> {
  CameraController? _kamera;
  bool _pripravuje = true;
  bool _pracuje = false;
  bool _svetlo = false;
  String? _chyba;

  @override
  void initState() {
    super.initState();
    _spustKameru();
  }

  @override
  void dispose() {
    _kamera?.dispose();
    super.dispose();
  }

  Future<void> _spustKameru() async {
    try {
      final kamery = await availableCameras();
      final zadni = kamery.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kamery.first,
      );

      final controller = CameraController(
        zadni,
        // Vyšší rozlišení kvůli malému písmu na štítku; nižší by se
        // sice přeneslo rychleji, ale VIN by se často nepřečetl.
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      // Ostření na blízko - štítek se fotí z dvaceti centimetrů.
      await controller.setFocusMode(FocusMode.auto);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _kamera = controller;
        _pripravuje = false;
      });
    } on CameraException catch (chyba) {
      if (!mounted) return;
      setState(() {
        _pripravuje = false;
        _chyba = chyba.code == 'CameraAccessDenied'
            ? 'Aplikace nemá přístup k fotoaparátu. Povolte ho v nastavení telefonu.'
            : 'Fotoaparát se nepodařilo spustit (${chyba.code}).';
      });
    }
  }

  Future<void> _prepniSvetlo() async {
    final kamera = _kamera;
    if (kamera == null) return;
    try {
      await kamera.setFlashMode(_svetlo ? FlashMode.off : FlashMode.torch);
      setState(() => _svetlo = !_svetlo);
    } on CameraException {
      // Některá zařízení svítilnu při náhledu neumí - není to důvod
      // cokoli hlásit, jen se tlačítko chová jako by nic.
    }
  }

  Future<void> _vyfot() async {
    final kamera = _kamera;
    if (kamera == null || _pracuje) return;

    setState(() => _pracuje = true);
    try {
      final snimek = await kamera.takePicture();
      final kody = await ref.read(skenerProvider).precti(snimek.path);

      if (!mounted) return;
      if (kody.isEmpty) {
        setState(() => _pracuje = false);
        _zprava('Nic se nenašlo. Zkuste to blíž, nebo přisviťte.');
        return;
      }

      final vybrany = kody.length == 1 ? kody.single : await _vyberKod(kody);
      if (!mounted) return;
      if (vybrany == null) {
        setState(() => _pracuje = false);
        return;
      }
      widget.onNalezeno(vybrany);
    } catch (chyba) {
      if (!mounted) return;
      setState(() => _pracuje = false);
      _zprava('Snímek se nepodařilo zpracovat: $chyba');
    }
  }

  Future<KodVozidla?> _vyberKod(List<KodVozidla> kody) {
    return showModalBottomSheet<KodVozidla>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: Text('Co se má hledat?'),
            ),
            for (final kod in kody)
              ListTile(
                leading: Icon(
                  kod.druh == DruhKodu.vin
                      ? Icons.tag_rounded
                      : Icons.directions_car_rounded,
                ),
                title: Text(kod.hodnota),
                subtitle: Text(kod.druh.label),
                onTap: () => Navigator.of(context).pop(kod),
              ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  void _zprava(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final kamera = _kamera;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (kamera != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: kamera.value.previewSize?.height ?? 1,
                height: kamera.value.previewSize?.width ?? 1,
                child: CameraPreview(kamera),
              ),
            ),
          if (_pripravuje)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_chyba != null) _Chyba(text: _chyba!),
          if (kamera != null) const _Ramecek(),
          _Ovladani(
            svetlo: _svetlo,
            pracuje: _pracuje,
            muzeFotit: kamera != null && _chyba == null,
            onSvetlo: _prepniSvetlo,
            onVyfot: _vyfot,
            onZpet: widget.onBack,
          ),
        ],
      ),
    );
  }
}

/// Rámeček, kam mířit. Okolí je ztmavené, ať je jasné, co se čte.
class _Ramecek extends StatelessWidget {
  const _Ramecek();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Široký a nízký - VIN i SPZ jsou vždycky na jednom řádku.
        final sirka = constraints.maxWidth * 0.86;
        final vyska = sirka * 0.28;

        return Stack(
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: sirka,
                      height: vyska,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                width: sirka,
                height: vyska,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 2),
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: vyska + Insets.huge),
                child: Text(
                  'Namiřte na VIN nebo SPZ',
                  style: AppTextStyles.cardBody.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Ovladani extends StatelessWidget {
  const _Ovladani({
    required this.svetlo,
    required this.pracuje,
    required this.muzeFotit,
    required this.onSvetlo,
    required this.onVyfot,
    required this.onZpet,
  });

  final bool svetlo;
  final bool pracuje;
  final bool muzeFotit;
  final VoidCallback onSvetlo;
  final VoidCallback onVyfot;
  final VoidCallback onZpet;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onZpet,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Zavřít',
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.giant),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Štítek s VINem bývá na tmavém místě pod kapotou.
                IconButton(
                  onPressed: muzeFotit ? onSvetlo : null,
                  icon: Icon(
                    svetlo ? Icons.flashlight_on : Icons.flashlight_off,
                    color: Colors.white,
                  ),
                  tooltip: 'Přisvítit',
                ),
                const SizedBox(width: Insets.giant),
                _Spoust(pracuje: pracuje, onTap: muzeFotit ? onVyfot : null),
                const SizedBox(width: Insets.giant),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Spoust extends StatelessWidget {
  const _Spoust({required this.pracuje, required this.onTap});

  final bool pracuje;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vyfotit',
      child: GestureDetector(
        onTap: pracuje ? null : onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: onTap == null ? 0.3 : 1),
            border: Border.all(color: Colors.white54, width: 4),
          ),
          child: pracuje
              ? const Padding(
                  padding: EdgeInsets.all(Insets.xxl),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : null,
        ),
      ),
    );
  }
}

class _Chyba extends StatelessWidget {
  const _Chyba({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white54,
              size: 44,
            ),
            const SizedBox(height: Insets.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
