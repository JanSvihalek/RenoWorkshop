import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../domain/entities/dokument.dart';
import '../../domain/entities/fotka.dart';
import '../controllers/fotky_providers.dart';

/// Karta Fotodokumentace v detailu zakázky - kolik fotek je a v jakých
/// kategoriích. Klepnutím se otevře obrazovka s kategoriemi.
///
/// Fotky jsou u zakázky, ne u příjmu: fotí se i během opravy (poškození
/// skryté pod dílem) nebo před předáním, a pokaždé se hledají na stejném
/// místě.
class FotodokumentaceKarta extends ConsumerWidget {
  const FotodokumentaceKarta({
    super.key,
    required this.orderId,
    required this.onOtevrit,
  });

  final String orderId;
  final VoidCallback onOtevrit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final fotky = ref.watch(fotkyZakazkyProvider(orderId));
    final nahravane = ref.watch(nahravaniFotekProvider(orderId));
    final selhalo = nahravane.where((f) => f.selhala).length;
    final nahrava = nahravane.length - selhalo;

    final nahrane = fotky.valueOrNull ?? const <Fotka>[];
    // Dokumenty (PDF a vše mimo kategorie fotek) se jen připočítají -
    // když se nenačtou, karta kvůli nim chybu neukazuje.
    final dokumenty =
        ref.watch(dokumentyZakazkyProvider(orderId)).valueOrNull ??
        const <Dokument>[];
    final prazdna = nahrane.isEmpty && dokumenty.isEmpty;
    final kategorie = [
      for (final k in KategorieFotky.values)
        if (nahrane.any((f) => f.kategorie == k)) k,
    ];

    final String popis;
    if (fotky.hasError && !fotky.hasValue) {
      popis = 'Fotky se nepodařilo načíst.';
    } else if (!fotky.hasValue) {
      popis = 'Načítám fotky…';
    } else if (prazdna) {
      popis = 'Zatím bez fotek a dokumentů.';
    } else {
      popis = [
        if (nahrane.isNotEmpty) pocetFotek(nahrane.length),
        if (kategorie.isNotEmpty)
          kategorie.map((k) => k.kratkyNazev).join(', '),
        if (dokumenty.isNotEmpty) pocetDokumentu(dokumenty.length),
      ].join(' · ');
    }

    return Semantics(
      button: true,
      label: 'Otevřít fotodokumentaci',
      child: GestureDetector(
        key: const Key('otevrit-fotodokumentaci'),
        onTap: onOtevrit,
        behavior: HitTestBehavior.opaque,
        child: DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SectionLabel(
                      nahrane.isEmpty
                          ? 'FOTODOKUMENTACE'
                          : 'FOTODOKUMENTACE  ${nahrane.length}',
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: palette.muted,
                  ),
                ],
              ),
              if (nahrane.isNotEmpty) ...[
                const SizedBox(height: Insets.sm),
                _Nahledy(fotky: nahrane),
              ],
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Icon(
                    prazdna
                        ? Icons.add_a_photo_outlined
                        : Icons.photo_library_outlined,
                    size: 20,
                    color: prazdna ? AppColors.accent : palette.muted,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      popis,
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                      ),
                    ),
                  ),
                ],
              ),
              // Rozpracované nahrávání je vidět i odsud - technik z fotek
              // odejde, zatímco se dohrávají, a potřebuje vědět, že nejsou
              // na serveru.
              if (nahrava > 0 || selhalo > 0) ...[
                const SizedBox(height: Insets.xs),
                Text(
                  [
                    if (nahrava > 0) 'Nahrává se: $nahrava',
                    if (selhalo > 0) 'Nenahráno: $selhalo',
                  ].join(' · '),
                  style: AppTextStyles.metaSmall.copyWith(
                    color: selhalo > 0 ? AppColors.danger : palette.muted,
                    fontWeight: selhalo > 0 ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Prvních pár náhledů a dlaždice „+N Zobrazit vše". Klepnutí kamkoli
/// otevře fotodokumentaci.
class _Nahledy extends StatelessWidget {
  const _Nahledy({required this.fotky});

  final List<Fotka> fotky;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Čtverečky kolem 64 px, poslední místo pro „+N".
        const mezera = Insets.sm;
        final mist = ((constraints.maxWidth + mezera) / (64 + mezera))
            .floor()
            .clamp(3, 8);
        final strana = (constraints.maxWidth - mezera * (mist - 1)) / mist;
        final zbyva = fotky.length > mist ? fotky.length - (mist - 1) : 0;
        final viditelne = fotky.take(zbyva > 0 ? mist - 1 : mist).toList();
        return Row(
          children: [
            for (final (i, f) in viditelne.indexed) ...[
              if (i > 0) const SizedBox(width: mezera),
              _Nahled(fotka: f, strana: strana),
            ],
            if (zbyva > 0) ...[
              const SizedBox(width: mezera),
              Container(
                key: const Key('fotky-zobrazit-vse'),
                width: strana,
                height: strana,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(Radii.input),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+$zbyva',
                      style: AppTextStyles.cardBody.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Zobrazit vše',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Nahled extends ConsumerWidget {
  const _Nahled({required this.fotka, required this.strana});

  final Fotka fotka;
  final double strana;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final obrazek = ref.watch(nahledFotkyProvider(fotka.id));
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.input),
      child: Container(
        width: strana,
        height: strana,
        color: palette.plate,
        child: obrazek.when(
          data: (bajty) => Image.memory(
            bajty,
            fit: BoxFit.cover,
            cacheWidth: 200,
            gaplessPlayback: true,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) =>
              Icon(Icons.broken_image_outlined, color: palette.muted),
        ),
      ),
    );
  }
}
