import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/zavada.dart';
import 'detail_cards.dart';

/// Závady na zakázce z Heliosu - co má dílna na voze udělat.
///
/// Jen ke čtení: závady zapisuje poradce v Heliosu a aplikace je přebírá.
/// Když se v Heliosu změní, do pěti minut se to projeví i tady.
class ZavadyCard extends StatelessWidget {
  const ZavadyCard({super.key, required this.zavady});

  final List<Zavada> zavady;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('ZÁVADY')),
              if (zavady.isNotEmpty)
                Text(
                  '${zavady.length}',
                  style: AppTextStyles.orderNumber.copyWith(
                    fontSize: 11.5,
                    color: palette.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.base),
          if (zavady.isEmpty)
            Text(
              'V Heliosu nejsou u zakázky zapsané žádné závady.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          for (final (poradi, zavada) in zavady.indexed)
            _RadekZavady(poradi: poradi + 1, zavada: zavada),
        ],
      ),
    );
  }
}

class _RadekZavady extends StatelessWidget {
  const _RadekZavady({required this.poradi, required this.zavada});

  final int poradi;
  final Zavada zavada;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
                if (zavada.kod case final kod?) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Závada $kod',
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
