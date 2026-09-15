import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../settings/domain/entities/nastaveni.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';
import '../../domain/entities/kod_vozidla.dart';
import '../controllers/orders_providers.dart';
import '../../domain/entities/vyrez_snimku.dart';
import '../controllers/ramecek_skeneru.dart';

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

  /// Rámeček i plocha, ke které patří. Podle ní se přepočítá na výřez
  /// z fotky, takže musí odpovídat tomu, co člověk vidí.
  RamecekSkeneru? _ramecek;
  bool _menilRamecek = false;

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
      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }
      // Ostření na blízko - štítek se fotí z dvaceti centimetrů. Jen pokus:
      // zařízení s pevným ostřením nastavení odmítne a skener musí běžet
      // i tak.
      try {
        await controller.setFocusMode(FocusMode.auto);
      } on CameraException {
        // Pevné ostření - není co nastavovat.
      }

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
    } catch (_) {
      // Zařízení bez fotoaparátu nebo plugin, který se nenačetl. Radši
      // hláška a funkční tlačítko Zavřít než spadlá obrazovka.
      if (!mounted) return;
      setState(() {
        _pripravuje = false;
        _chyba = 'Fotoaparát není k dispozici.';
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

  /// Rámeček pro danou plochu. Při prvním sestavení se založí výchozí,
  /// po otočení telefonu se přepočítá, jinak se vrátí ten, který si
  /// uživatel nastavil.
  RamecekSkeneru _ramecekPro(
    Size plocha, {
    required double vlevo,
    required double vpravo,
  }) {
    final soucasny = _ramecek;
    final novy = soucasny == null
        ? RamecekSkeneru.vychozi(plocha, vlevo: vlevo, vpravo: vpravo)
        : soucasny.sPlochou(plocha).sOkraji(vlevo: vlevo, vpravo: vpravo);
    _ramecek = novy;
    return novy;
  }

  /// Tažení za jednu stranu. Ostatní zůstanou, kde byly.
  void _tahniStranu(StranaRamecku strana, Offset posun) {
    final soucasny = _ramecek;
    if (soucasny == null) return;

    setState(() {
      _ramecek = soucasny.tahni(strana, posun);
      _menilRamecek = true;
    });
  }

  /// Jeden prst posouvá celý rámeček, dva mění velikost. Obojí přes
  /// stejné gesto, protože se počet prstů může během tahu změnit.
  void _menRamecek(ScaleUpdateDetails detaily) {
    final soucasny = _ramecek;
    if (soucasny == null) return;

    setState(() {
      _ramecek = detaily.pointerCount < 2
          ? soucasny.posunuty(detaily.focalPointDelta)
          : soucasny.zvetseny(
              vodorovne: detaily.horizontalScale,
              svisle: detaily.verticalScale,
            );
      _menilRamecek = true;
    });
  }

  void _vratRamecek() {
    final soucasny = _ramecek;
    if (soucasny == null) return;

    setState(() {
      _ramecek = RamecekSkeneru.vychozi(
        soucasny.plocha,
        vlevo: soucasny.vlevo,
        vpravo: soucasny.vpravo,
      );
      _menilRamecek = true;
    });
  }

  Future<void> _vyfot() async {
    final kamera = _kamera;
    if (kamera == null || _pracuje) return;

    setState(() => _pracuje = true);
    try {
      final snimek = await kamera.takePicture();
      final ramecek = _ramecek;
      final kody = await ref
          .read(skenerProvider)
          .precti(
            snimek.path,
            ramecek: ramecek?.obdelnik,
            plochaNahledu: ramecek?.plocha,
          );

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
    final spoust = ref.watch(nastaveniProvider).spoust;
    final bezpecne = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Spoušť na boku: rámeček se vyhne pruhu s tlačítky, jinak by je
          // na úzkém telefonu překrýval a za okraj pod nimi by nešlo vzít.
          final ramecek = _ramecekPro(
            constraints.biggest,
            vlevo: spoust == UmisteniSpouste.vlevo
                ? bezpecne.left + _Ovladani.sirkaPruhu
                : RamecekSkeneru.okraj,
            vpravo: spoust == UmisteniSpouste.vpravo
                ? bezpecne.right + _Ovladani.sirkaPruhu
                : RamecekSkeneru.okraj,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              if (kamera != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.fromSize(
                    size: VyrezSnimku.velikostNahledu(
                      nahledKamery:
                          kamera.value.previewSize ?? const Size(16, 9),
                      plocha: constraints.biggest,
                    ),
                    child: CameraPreview(kamera),
                  ),
                ),
              if (_pripravuje)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_chyba != null) _Chyba(text: _chyba!),
              if (kamera != null)
                GestureDetector(
                  // Celá plocha náhledu, ať se nemusí trefovat do rámečku.
                  behavior: HitTestBehavior.opaque,
                  onScaleUpdate: _menRamecek,
                  onDoubleTap: _vratRamecek,
                  child: _Ramecek(
                    ramecek: ramecek.obdelnik,
                    ukazNapovedu: !_menilRamecek,
                    onTahni: _tahniStranu,
                  ),
                ),
              // Až za rámečkem, aby tlačítka dostala doteky přednostně.
              _Ovladani(
                umisteni: spoust,
                svetlo: _svetlo,
                pracuje: _pracuje,
                muzeFotit: kamera != null && _chyba == null,
                onSvetlo: _prepniSvetlo,
                onVyfot: _vyfot,
                onZpet: widget.onBack,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rámeček, kam mířit. Okolí je ztmavené, ať je jasné, co se čte —
/// a čte se doopravdy jen jeho obsah, snímek se na něj ořízne.
class _Ramecek extends StatelessWidget {
  const _Ramecek({
    required this.ramecek,
    required this.ukazNapovedu,
    required this.onTahni,
  });

  final Rect ramecek;

  /// Napoví, jak se velikost mění. Zmizí, jakmile to člověk jednou udělá —
  /// pak už jen překáží.
  final bool ukazNapovedu;

  final void Function(StranaRamecku strana, Offset posun) onTahni;

  @override
  Widget build(BuildContext context) {
    if (ramecek.isEmpty) return const SizedBox.shrink();

    final okraje = EdgeInsets.only(left: ramecek.left, top: ramecek.top);
    final tvar = BorderRadius.circular(Radii.button);

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
              Padding(
                padding: okraje,
                child: Container(
                  width: ramecek.width,
                  height: ramecek.height,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: tvar,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: okraje,
          child: Container(
            width: ramecek.width,
            height: ramecek.height,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 2),
              borderRadius: tvar,
            ),
          ),
        ),
        // Úchyty až nad rámečkem, aby doteky bral tah za stranu, ne
        // gesto pod nimi.
        _Uchyt(
          strana: StranaRamecku.vlevo,
          stred: Offset(ramecek.left, ramecek.center.dy),
          onTahni: onTahni,
        ),
        _Uchyt(
          strana: StranaRamecku.vpravo,
          stred: Offset(ramecek.right, ramecek.center.dy),
          onTahni: onTahni,
        ),
        _Uchyt(
          strana: StranaRamecku.nahore,
          stred: Offset(ramecek.center.dx, ramecek.top),
          onTahni: onTahni,
        ),
        _Uchyt(
          strana: StranaRamecku.dole,
          stred: Offset(ramecek.center.dx, ramecek.bottom),
          onTahni: onTahni,
        ),
        Positioned(
          top: ramecek.bottom + Insets.giant,
          left: Insets.xl,
          right: Insets.xl,
          child: Column(
            children: [
              Text(
                'Namiřte na VIN nebo SPZ',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardBody.copyWith(color: Colors.white),
              ),
              if (ukazNapovedu) ...[
                const SizedBox(height: Insets.xs),
                Text(
                  'Táhněte za strany rámečku, dvojklik ho vrátí zpět',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardBody.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Úchyt na straně rámečku. Táhne se jedním prstem a hýbe jen svou stranou.
class _Uchyt extends StatelessWidget {
  const _Uchyt({
    required this.strana,
    required this.stred,
    required this.onTahni,
  });

  final StranaRamecku strana;

  /// Střed úchytu na obrazovce — leží přímo na hraně rámečku.
  final Offset stred;

  final void Function(StranaRamecku strana, Offset posun) onTahni;

  /// Doteková plocha na rukavici; čára samotná je mnohem tenčí.
  static const double _plocha = Sizes.minTouchTarget;

  @override
  Widget build(BuildContext context) {
    final naVysku =
        strana == StranaRamecku.vlevo || strana == StranaRamecku.vpravo;

    return Positioned(
      left: stred.dx - _plocha / 2,
      top: stred.dy - _plocha / 2,
      width: _plocha,
      height: _plocha,
      child: Semantics(
        label: 'Změnit velikost rámečku',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (detaily) => onTahni(strana, detaily.delta),
          child: Center(
            child: Container(
              width: naVysku ? 5 : 30,
              height: naVysku ? 30 : 5,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(Radii.badge),
                // Aby byl úchyt vidět i na světlém pozadí.
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ovladani extends StatelessWidget {
  const _Ovladani({
    required this.umisteni,
    required this.svetlo,
    required this.pracuje,
    required this.muzeFotit,
    required this.onSvetlo,
    required this.onVyfot,
    required this.onZpet,
  });

  final UmisteniSpouste umisteni;
  final bool svetlo;
  final bool pracuje;
  final bool muzeFotit;
  final VoidCallback onSvetlo;
  final VoidCallback onVyfot;
  final VoidCallback onZpet;

  /// Šířka pruhu u kraje, který zabírá sloupec se spouští na boku - odstup
  /// od kraje, spoušť a mezera k rámečku.
  static const double sirkaPruhu = Insets.xl + _Spoust.prumer + Insets.xl;

  @override
  Widget build(BuildContext context) {
    final svetlo = IconButton(
      onPressed: muzeFotit ? onSvetlo : null,
      icon: Icon(
        this.svetlo ? Icons.flashlight_on : Icons.flashlight_off,
        color: Colors.white,
      ),
      tooltip: 'Přisvítit',
    );
    final spoust = _Spoust(pracuje: pracuje, onTap: muzeFotit ? onVyfot : null);

    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: onZpet,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Zavřít',
            ),
          ),
          switch (umisteni) {
            UmisteniSpouste.dole => Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Insets.giant),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Štítek s VINem bývá na tmavém místě pod kapotou.
                    svetlo,
                    const SizedBox(width: Insets.giant),
                    spoust,
                    const SizedBox(width: Insets.giant),
                    // Protiváha svítilny, ať je spoušť opravdu uprostřed.
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            // Na boku uprostřed výšky - tam, kam sahá palec ruky, která
            // tablet drží. Svítilna nad spouští, ať ji palec nezakrývá.
            UmisteniSpouste.vlevo || UmisteniSpouste.vpravo => Align(
              alignment: umisteni == UmisteniSpouste.vlevo
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
                child: Column(
                  key: const Key('spoust-na-boku'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    svetlo,
                    const SizedBox(height: Insets.xl),
                    spoust,
                  ],
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _Spoust extends StatelessWidget {
  const _Spoust({required this.pracuje, required this.onTap});

  static const double prumer = 72;

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
          width: prumer,
          height: prumer,
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
