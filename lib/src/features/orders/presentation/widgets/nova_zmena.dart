import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/nova_zmena.dart';

/// Modrá tečka nové změny - stejná v kartě, tabulce, liště i navigaci.
class TeckaZmeny extends StatelessWidget {
  const TeckaZmeny({super.key, this.velikost = 8});

  final double velikost;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: velikost,
      height: velikost,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            spreadRadius: 3,
          ),
        ],
      ),
    );
  }
}

/// Pozadí pruhu nové změny - jemně modré v obou režimech.
Color pozadiZmeny(BuildContext context) => Color.alphaBlend(
  AppColors.accent.withValues(alpha: context.isDarkMode ? 0.2 : 0.12),
  context.palette.card,
);

/// Pruh nahoře v kartě: „● Nový stav: Lakovna  +1   Eva Malá · 10:05".
class PruhNoveZmeny extends StatelessWidget {
  const PruhNoveZmeny({super.key, required this.zmena});

  final NovaZmena zmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ted = DateTime.now();

    return Tooltip(
      message: '${zmena.text}\n${zmena.kdoKdy(ted)}',
      child: Container(
        key: const Key('karta-nova-zmena'),
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 5),
        decoration: BoxDecoration(
          color: pozadiZmeny(context),
          borderRadius: BorderRadius.circular(Radii.badge),
        ),
        child: Row(
          children: [
            const TeckaZmeny(),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                zmena.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.metaSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ),
            if (zmena.pocet > 1) ...[
              const SizedBox(width: Insets.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text(
                  '+${zmena.pocet - 1}',
                  style: AppTextStyles.badge.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(width: Insets.sm),
            Text(
              zmena.kdoKdy(ted),
              maxLines: 1,
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pruh nahoře v detailu: co bylo nového při otevření. Zůstane, i když
/// štítek v seznamu hned zmizí; křížkem se schová.
class PruhOdPosledniNavstevy extends StatelessWidget {
  const PruhOdPosledniNavstevy({
    super.key,
    required this.zmena,
    required this.onSkryt,
  });

  final NovaZmena zmena;
  final VoidCallback onSkryt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dalsi = zmena.pocet > 1 ? ' a ${zmena.pocet - 1} další' : '';

    return Container(
      key: const Key('detail-nova-zmena'),
      padding: const EdgeInsets.fromLTRB(Insets.base, Insets.xs, 0, Insets.xs),
      decoration: BoxDecoration(
        color: pozadiZmeny(context),
        borderRadius: BorderRadius.circular(Radii.card),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 4),
        ),
      ),
      child: Row(
        children: [
          const TeckaZmeny(),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Od vaší poslední návštěvy: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '${zmena.text}$dalsi'),
                  TextSpan(
                    text: ' · ${zmena.kdoKdy(DateTime.now())}',
                    style: TextStyle(color: palette.muted),
                  ),
                ],
              ),
              style: AppTextStyles.cardBody.copyWith(
                fontSize: 13.5,
                color: palette.text,
              ),
            ),
          ),
          IconButton(
            key: const Key('detail-nova-zmena-skryt'),
            tooltip: 'Skrýt',
            visualDensity: VisualDensity.compact,
            onPressed: onSkryt,
            icon: Icon(Icons.close_rounded, size: 18, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
