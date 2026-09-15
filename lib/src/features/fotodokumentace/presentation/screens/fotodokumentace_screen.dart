import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../domain/entities/fotka.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';
import '../controllers/fotky_providers.dart';
import '../ulozeni_do_zarizeni.dart';
import '../ziskani_fotek.dart';

/// Fotodokumentace zakázky - karta na každou kategorii. Otevírá se
/// z detailu zakázky.
///
/// Fotky se nahrávají hned po pořízení, jedna za druhou. Když nahrání
/// selže (hala bez signálu), fotka zůstane na kartě s červeným rámečkem
/// a jde poslat znovu.
class FotodokumentaceScreen extends ConsumerWidget {
  const FotodokumentaceScreen({
    super.key,
    required this.orderId,
    required this.onBack,
  });

  final String orderId;
  final VoidCallback onBack;

  Future<void> _zGalerie(
    BuildContext context,
    WidgetRef ref,
    KategorieFotky kategorie,
  ) async {
    final fotky = await ref.read(ziskaniFotekProvider).zGalerie(context);
    if (fotky.isEmpty) return;
    await ref
        .read(nahravaniFotekProvider(orderId).notifier)
        .pridej(kategorie, fotky);
  }

  Future<void> _fotit(
    BuildContext context,
    WidgetRef ref,
    KategorieFotky kategorie,
  ) {
    final nahravani = ref.read(nahravaniFotekProvider(orderId).notifier);
    return ref
        .read(ziskaniFotekProvider)
        .foceni(
          context,
          nadpis: kategorie.nazev,
          onFotka: (fotka) {
            // Do telefonu jen z fotoaparátu - fotky z galerie v něm už jsou.
            // Záloha běží vedle nahrávání a nečeká se na ni.
            if (ref.read(nastaveniProvider).ukladatFotkyDoZarizeni) {
              _ulozDoZarizeni(context, ref, kategorie, fotka);
            }
            nahravani.pridej(kategorie, [fotka]);
          },
        );
  }

  Future<void> _ulozDoZarizeni(
    BuildContext context,
    WidgetRef ref,
    KategorieFotky kategorie,
    Uint8List fotka,
  ) async {
    try {
      await ref
          .read(ulozeniDoZarizeniProvider)
          .uloz(
            fotka,
            nazev: nazevFotkyVZarizeni(orderId, kategorie, DateTime.now()),
          );
    } catch (chyba) {
      // Technik spoléhá, že fotku v telefonu má - když tam není, musí to
      // vědět hned, ne až ji bude hledat.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              chyba is UlozeniDoZarizeniException
                  ? chyba.message
                  : 'Fotku se nepodařilo uložit do telefonu.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final zakazka = ref.watch(orderByIdProvider(orderId)).valueOrNull;
    final fotky = ref.watch(fotkyZakazkyProvider(orderId));
    final nahravane = ref.watch(nahravaniFotekProvider(orderId));

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _Hlavicka(
            onBack: onBack,
            spz: zakazka?.licensePlate,
            model: zakazka?.model,
            cisloZakazky: orderId,
          ),
          if (fotky.hasError)
            _ChybaNacteni(
              zprava: fotky.error is ServiceOrderException
                  ? (fotky.error! as ServiceOrderException).message
                  : 'Fotky se nepodařilo načíst.',
              onZnovu: () => ref.invalidate(fotkyZakazkyProvider(orderId)),
            ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () async =>
                  ref.invalidate(fotkyZakazkyProvider(orderId)),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Insets.xl,
                  Insets.lg,
                  Insets.xl,
                  Insets.giant + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: KategorieFotky.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
                itemBuilder: (context, index) {
                  final kategorie = KategorieFotky.values[index];
                  return _KartaKategorie(
                    kategorie: kategorie,
                    nacita: fotky.isLoading && !fotky.hasValue,
                    fotky: [
                      for (final fotka in fotky.valueOrNull ?? const <Fotka>[])
                        if (fotka.kategorie == kategorie) fotka,
                    ],
                    nahravane: [
                      for (final fotka in nahravane)
                        if (fotka.kategorie == kategorie) fotka,
                    ],
                    onGalerie: () => _zGalerie(context, ref, kategorie),
                    onFotit: () => _fotit(context, ref, kategorie),
                    onOtevrit: (fotka) => _ProhlizeniFotky.otevri(
                      context,
                      orderId: orderId,
                      fotka: fotka,
                    ),
                    onNahravana: (fotka) =>
                        _nabidkaNahravane(context, ref, fotka),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _nabidkaNahravane(
    BuildContext context,
    WidgetRef ref,
    NahravanaFotka fotka,
  ) async {
    if (!fotka.selhala) return;
    final nahravani = ref.read(nahravaniFotekProvider(orderId).notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: Text(
                fotka.chyba ?? '',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardBody.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ),
            const SizedBox(height: Insets.base),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Zkusit znovu'),
              onTap: () {
                Navigator.of(sheet).pop();
                nahravani.znovu(fotka.klic);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Zahodit fotku'),
              onTap: () {
                Navigator.of(sheet).pop();
                nahravani.zahod(fotka.klic);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Hlavicka extends StatelessWidget {
  const _Hlavicka({
    required this.onBack,
    required this.cisloZakazky,
    this.spz,
    this.model,
  });

  final VoidCallback onBack;
  final String cisloZakazky;
  final String? spz;
  final String? model;

  @override
  Widget build(BuildContext context) {
    final isIOS = context.isIOS;
    final podtitulek = [
      if (model != null && model!.isNotEmpty) model!,
      cisloZakazky,
    ].join(' · ');

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.base,
        MediaQuery.paddingOf(context).top + Insets.base,
        Insets.xxl,
        Insets.xl,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zpět',
            onPressed: onBack,
            icon: Icon(
              isIOS
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: Insets.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fotodokumentace',
                  style: AppTextStyles.appBarTitle(
                    isIOS: isIOS,
                  ).copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (spz != null && spz!.isNotEmpty) spz!,
                    podtitulek,
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.appBarMeta.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChybaNacteni extends StatelessWidget {
  const _ChybaNacteni({required this.zprava, required this.onZnovu});

  final String zprava;
  final VoidCallback onZnovu;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.danger.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              zprava,
              style: AppTextStyles.cardBody.copyWith(color: AppColors.danger),
            ),
          ),
          TextButton(onPressed: onZnovu, child: const Text('Znovu')),
        ],
      ),
    );
  }
}

/// Karta jedné kategorie: ikona, název, přidání z galerie, focení
/// a miniatury pořízených fotek.
class _KartaKategorie extends StatelessWidget {
  const _KartaKategorie({
    required this.kategorie,
    required this.nacita,
    required this.fotky,
    required this.nahravane,
    required this.onGalerie,
    required this.onFotit,
    required this.onOtevrit,
    required this.onNahravana,
  });

  final KategorieFotky kategorie;
  final bool nacita;
  final List<Fotka> fotky;
  final List<NahravanaFotka> nahravane;
  final VoidCallback onGalerie;
  final VoidCallback onFotit;
  final void Function(Fotka fotka) onOtevrit;
  final void Function(NahravanaFotka fotka) onNahravana;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pocet = fotky.length + nahravane.length;
    // Zelený rámeček: kategorie je nafocená. Na první pohled je vidět, co
    // při obchůzce ještě chybí.
    final hotovo = fotky.isNotEmpty;

    return Container(
      key: Key('kategorie-${kategorie.klic}'),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card + 4),
        border: Border.all(
          color: hotovo
              ? AppColors.heliosGreen.withValues(alpha: 0.6)
              : palette.hairline,
          width: hotovo ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.base,
        Insets.sm,
        Insets.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kategorie.ikona, color: AppColors.accent, size: 28),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kategorie.nazev,
                      style: AppTextStyles.cardModel.copyWith(
                        color: palette.text,
                      ),
                    ),
                    if (pocet > 0)
                      Text(
                        pocetFotek(pocet),
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.muted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Přidat z galerie',
                onPressed: onGalerie,
                icon: Icon(Icons.photo_library_rounded, color: palette.muted),
              ),
              IconButton(
                tooltip: 'Vyfotit',
                onPressed: onFotit,
                icon: const Icon(
                  Icons.add_a_photo_rounded,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          if (pocet > 0) ...[
            const SizedBox(height: Insets.sm),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Rozpracované první - na ty technik právě čeká.
                  for (final fotka in nahravane)
                    _MiniaturaNahravana(
                      fotka: fotka,
                      onTap: () => onNahravana(fotka),
                    ),
                  for (final fotka in fotky)
                    _Miniatura(fotka: fotka, onTap: () => onOtevrit(fotka)),
                ],
              ),
            ),
          ] else if (nacita)
            const Padding(
              padding: EdgeInsets.only(top: Insets.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _Miniatura extends ConsumerWidget {
  const _Miniatura({required this.fotka, required this.onTap});

  final Fotka fotka;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final obrazek = ref.watch(obrazekFotkyProvider(fotka.id));

    return Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.input),
          child: Container(
            width: 80,
            height: 80,
            color: palette.plate,
            child: obrazek.when(
              data: (bajty) => Image.memory(
                bajty,
                fit: BoxFit.cover,
                // Dekódovat jen v rozměru miniatury, ne 2000 px.
                cacheWidth: 240,
                gaplessPlayback: true,
              ),
              loading: () => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) =>
                  Icon(Icons.broken_image_outlined, color: palette.muted),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniaturaNahravana extends StatelessWidget {
  const _MiniaturaNahravana({required this.fotka, required this.onTap});

  final NahravanaFotka fotka;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: Key(fotka.selhala ? 'fotka-selhala' : 'fotka-nahrava'),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.input),
            border: fotka.selhala
                ? Border.all(color: AppColors.danger, width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.input - 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  fotka.jpeg,
                  fit: BoxFit.cover,
                  cacheWidth: 240,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
                ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
                Center(
                  child: fotka.selhala
                      ? const Icon(Icons.refresh_rounded, color: Colors.white)
                      : const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fotka přes celou obrazovku - zvětšení prsty, kdo a kdy ji nahrál,
/// smazání.
class _ProhlizeniFotky extends ConsumerWidget {
  const _ProhlizeniFotky({required this.orderId, required this.fotka});

  final String orderId;
  final Fotka fotka;

  static Future<void> otevri(
    BuildContext context, {
    required String orderId,
    required Fotka fotka,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ProhlizeniFotky(orderId: orderId, fotka: fotka),
      ),
    );
  }

  Future<void> _smaz(BuildContext context, WidgetRef ref) async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog.adaptive(
        title: const Text('Smazat fotku?'),
        content: const Text(
          'Fotka zmizí z aplikace i ze sdílené složky na serveru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (potvrzeno != true || !context.mounted) return;

    try {
      await ref.read(fotkyDataSourceProvider).smazFotku(fotka.id);
      ref.invalidate(fotkyZakazkyProvider(orderId));
      if (context.mounted) Navigator.of(context).pop();
    } on ServiceOrderException catch (chyba) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(chyba.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obrazek = ref.watch(obrazekFotkyProvider(fotka.id));
    final popis = [
      fotka.kategorie.nazev,
      AppDateFormat.dateTime(fotka.nahranoAt),
      if (fotka.nahralKdo != null) fotka.nahralKdo!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          popis,
          style: AppTextStyles.metaSmall.copyWith(color: Colors.white70),
        ),
        actions: [
          IconButton(
            tooltip: 'Smazat fotku',
            onPressed: () => _smaz(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Center(
        child: obrazek.when(
          data: (bajty) => InteractiveViewer(
            maxScale: 6,
            child: Image.memory(bajty, fit: BoxFit.contain),
          ),
          loading: () => const CircularProgressIndicator(color: Colors.white),
          error: (_, _) => const Text(
            'Fotku se nepodařilo načíst.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
