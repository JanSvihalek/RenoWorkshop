import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/prani_zakaznika.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/zavada.dart';
import '../controllers/order_actions_controller.dart';
import '../controllers/orders_providers.dart';
import 'detail_cards.dart';
import 'pridat_stav_sheet.dart';

/// Závady na zakázce z Heliosu - co má dílna na voze udělat.
///
/// Závady zapisuje poradce v Heliosu a aplikace je přebírá. Když se v Heliosu
/// změní, do pěti minut se to projeví i tady, proto je karta zelená jako
/// všechno z Heliosu. Dílna u nich jen zapisuje Zahájit a Dokončit - jako
/// dílenské stavy, takže jsou vidět i v průběhu opravy.
class ZavadyCard extends ConsumerWidget {
  const ZavadyCard({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final zavady = order.zavady;
    // Stejná práva jako průběh opravy, do kterého se závada zapisuje.
    final smi =
        ref.watch(smiPlanovatProvider(order.branch?.code)) ||
        ref.watch(smiZapisovatProvider(order.poradac?.kod));

    return DetailCard(
      key: const Key('zavady-karta'),
      zHeliosu: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pružný: na úzkém telefonu se nadpis zalomí, značka vedle
              // něj zůstane celá.
              // Nadpis s počtem si vezme všechno místo vedle značky; zalomí
              // se, až když se opravdu nevejde.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: SectionLabel(
                        'ZÁVADY/ÚKONY',
                        barva: AppColors.heliosZelena(context),
                      ),
                    ),
                    if (zavady.isNotEmpty) ...[
                      const SizedBox(width: Insets.sm),
                      Text(
                        '${zavady.length}',
                        style: AppTextStyles.orderNumber.copyWith(
                          fontSize: 11.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              const HeliosZnacka(),
            ],
          ),
          const SizedBox(height: Insets.base),
          if (zavady.isEmpty)
            Text(
              'V Heliosu nejsou u zakázky zapsané žádné závady.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          // Na širší kartě (tablet, web) ve dvou sloupcích - jako návrh.
          if (zavady.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final dvaSloupce = constraints.maxWidth >= 520;
                final sirka = dvaSloupce
                    ? (constraints.maxWidth - Insets.xl) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: Insets.xl,
                  children: [
                    for (final (poradi, zavada) in zavady.indexed)
                      SizedBox(
                        width: sirka,
                        child: _RadekZavady(
                          poradi: poradi + 1,
                          zavada: zavada,
                          order: order,
                          smi: smi,
                        ),
                      ),
                  ],
                );
              },
            ),
          // Řádky závad mají mezeru pod sebou, prázdná karta ne.
          if (order.prani case final prani?) ...[
            if (zavady.isEmpty) const SizedBox(height: Insets.base),
            _PraniZakaznika(prani: prani),
          ],
        ],
      ),
    );
  }
}

/// Co má mechanik kromě závad udělat. Ano je výrazné, ať se nepřehlédne.
class _PraniZakaznika extends StatelessWidget {
  const _PraniZakaznika({required this.prani});

  final PraniZakaznika prani;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget polozka(String nazev, bool? ano, [String? doplnek]) {
      final hodnota = switch (ano) {
        null => 'Nezadáno',
        false => 'Ne',
        true => doplnek == null ? 'Ano' : 'Ano · $doplnek',
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nazev,
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
          Text(
            hodnota,
            style: AppTextStyles.cardBody.copyWith(
              color: ano == true ? palette.text : palette.muted,
              fontWeight: ano == true ? FontWeight.w600 : null,
            ),
          ),
        ],
      );
    }

    return Column(
      key: const Key('prani-zakaznika'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: Insets.base),
        Text(
          'Ostatní přání',
          style: AppTextStyles.metaSmall.copyWith(
            color: palette.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.xl,
          runSpacing: Insets.sm,
          children: [
            polozka('Mytí', prani.myti, prani.mytiProgram),
            polozka('Vrátit vyměněné díly', prani.vratitDily),
            polozka('Provozní kapaliny', prani.provozniKapaliny),
          ],
        ),
      ],
    );
  }
}

class _RadekZavady extends ConsumerWidget {
  const _RadekZavady({
    required this.poradi,
    required this.zavada,
    required this.order,
    required this.smi,
  });

  final int poradi;
  final Zavada zavada;
  final ServiceOrder order;
  final bool smi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prubeh = stavZavady(zavada.id, order.historieStavu);
    final zaneprazdneno = ref.watch(orderActionsProvider).isLoading;
    final nazev = zavada.nazev;
    final poznamka = zavada.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$poradi.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stručný popis tučně, podrobnosti z poznámky pod ním menším
                // písmem. Starší závady bez popisu mají jen poznámku - ta
                // pak zastoupí popis, ať se nic neztratí.
                if (nazev != null) ...[
                  SelectableText(
                    nazev,
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (poznamka.isNotEmpty && poznamka != nazev) ...[
                    const SizedBox(height: 2),
                    SelectableText(
                      poznamka,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ] else
                  SelectableText(
                    poznamka.isEmpty ? 'Bez popisu' : poznamka,
                    style: AppTextStyles.cardBody.copyWith(
                      color: poznamka.isEmpty ? palette.muted : palette.text,
                    ),
                  ),
                // Kód z Heliosu bývá jen pořadové číslo - to už je vlevo.
                if (zavada.kod case final kod?
                    when !RegExp(r'^\d+$').hasMatch(kod.trim())) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Závada $kod',
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
                const SizedBox(height: Insets.xs),
                Wrap(
                  spacing: Insets.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (prubeh is ZavadaProbiha)
                      Text(
                        'Probíhá',
                        key: Key('zavada-probiha-${zavada.id}'),
                        style: AppTextStyles.metaSmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (prubeh case ZavadaHotova(:final kdy))
                      Text(
                        'Dokončeno ${AppDateFormat.date(kdy)}',
                        key: Key('zavada-hotovo-${zavada.id}'),
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    if (smi && prubeh is ZavadaCeka)
                      OutlinedButton(
                        key: Key('zavada-zahajit-${zavada.id}'),
                        onPressed: () => pridatStavZakazce(
                          context,
                          ref,
                          order,
                          zavada: zavada,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.base,
                          ),
                          textStyle: AppTextStyles.chip,
                        ),
                        child: const Text('Zahájit'),
                      ),
                    if (smi && prubeh is ZavadaProbiha)
                      FilledButton(
                        key: Key('zavada-dokoncit-${zavada.id}'),
                        onPressed: zaneprazdneno
                            ? null
                            : () => ref
                                  .read(orderActionsProvider.notifier)
                                  .dokonciStav(order.id, prubeh.zaznamId),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.base,
                          ),
                          // Tmavomodrá by na tmavém pozadí zanikla.
                          backgroundColor: context.isDarkMode
                              ? AppColors.accent
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          textStyle: AppTextStyles.chip,
                        ),
                        child: const Text('Dokončit'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
