import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';

/// Druh kampaně u vozu - podle něj barva a ikona štítku.
enum DruhStitku {
  /// Svolávací akce BMW podle VIN - oranžově, ať se nepřehlédne.
  technicka(Color(0xFFE8A93A), Color(0xFF2A1E05), Icons.car_repair_outlined),

  /// Kampaň podle stáří vozu (FitServis+) - modře, je to nabídka.
  podleStari(AppColors.accent, Colors.white, Icons.verified_outlined);

  const DruhStitku(this.vypln, this.text, this.ikona);

  final Color vypln;
  final Color text;
  final IconData ikona;
}

/// Kampaň u vozu - v hlavičce detailu zakázky a na kartě vozidla.
/// Klepnutí ukáže podrobnosti.
class StitekKampane extends StatelessWidget {
  const StitekKampane({
    super.key,
    required this.druh,
    required this.popisek,
    required this.nadpis,
    required this.podrobnosti,
    this.maly = false,
  });

  final DruhStitku druh;

  /// Text na štítku, např. „0032760300 · Výměna airbagu".
  final String popisek;

  /// Nadpis a text okna po klepnutí.
  final String nadpis;
  final String podrobnosti;

  /// Menší - v řádku s textem (první registrace a FitServis+).
  final bool maly;

  void _ukaz(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(nadpis),
        content: Text(podrobnosti),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: druh.vypln,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => _ukaz(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: maly ? Insets.sm : Insets.md,
            vertical: maly ? 2 : 5,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 2 * Insets.xxl,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(druh.ikona, size: maly ? 13 : 16, color: druh.text),
              const SizedBox(width: Insets.xs),
              Flexible(
                child: Text(
                  popisek,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    fontSize: maly ? 12 : null,
                    color: druh.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
