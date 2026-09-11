import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/dilensky_stav.dart';

/// Vizuální podoba dílenského stavu.
///
/// Stavy jsou nově číselník v databázi, ne pevný výčet, takže barvu nejde
/// každému přiřadit ručně. Odvozuje se proto z kódu: stejný stav má vždy
/// stejnou barvu, různé stavy se od sebe liší a nové stavy fungují samy
/// od sebe, bez zásahu do aplikace.
///
/// Barva tu není informace, jen pomůcka k rychlému rozlišení na dálku -
/// proto nevadí, že „červená" neznamená „problém".
extension DilenskyStavVisuals on DilenskyStav {
  static const _paleta = [
    AppColors.ink,
    AppColors.accent,
    AppColors.repairBlue,
    AppColors.qualityBlue,
    AppColors.readyGreen,
    AppColors.danger,
  ];

  Color get color {
    final klic = kod;
    // Ručně zapsaný stav je výjimka ze sledu prací a šedá ho odliší
    // od těch, na kterých se dílna domluvila.
    if (klic == null) return AppColors.pickedUpGrey;

    var soucet = 0;
    for (final znak in klic.codeUnits) {
      soucet = (soucet + znak) % _paleta.length;
    }
    return _paleta[soucet];
  }

  IconData get icon =>
      kod == null ? Icons.edit_note_outlined : Icons.check_circle_outline;
}
