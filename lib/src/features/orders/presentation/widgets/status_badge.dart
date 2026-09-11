import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/dilensky_stav.dart';
import 'order_status_visuals.dart';

/// Badge dílenského stavu - plná výplň, bílý text.
/// Plná výplň je záměr: musí být čitelná na dálku a v rukavicích.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.stav, this.fontSize = 11.5});

  /// `null` u zakázky, které stav ještě nikdo nedal.
  final DilenskyStav? stav;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final aktualni = stav;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      // Šířka badge se řídí textem stavu, který může být dlouhý
      // („Připraveno k vyzvednutí"), proto strop a tři tečky.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.45,
      ),
      decoration: BoxDecoration(
        color: aktualni?.color ?? AppColors.pickedUpGrey,
        borderRadius: BorderRadius.circular(Radii.badge),
      ),
      child: Text(
        aktualni?.nazev ?? 'Bez stavu',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.badge.copyWith(
          fontSize: fontSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
