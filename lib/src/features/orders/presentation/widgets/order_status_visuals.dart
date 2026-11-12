import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/dilensky_stav.dart';

/// Vizuální podoba dílenského stavu.
///
/// Všechny dílenské stavy mají jednu barvu, stejnou jako na webu:
/// tmavomodrou, v tmavém režimu modrou. Dřív se barva odvozovala z kódu
/// a některé stavy (Montáž) vyšly červeně, jako by šlo o problém - Jan
/// 12. 11. 2026 chtěl stavy sjednotit. Stav liší název, ne barva.
extension DilenskyStavVisuals on DilenskyStav {
  Color barva(BuildContext context) => barvaStavu(context);

  IconData get icon =>
      kod == null ? Icons.edit_note_outlined : Icons.check_circle_outline;

  /// Ikona kroku na dílně. Vlastní text má tužku; stav přidaný do číselníku
  /// bez vlastní ikony neutrální značku - doplní se v další verzi.
  IconData get ikonaKroku => switch (kod) {
    null => Icons.edit_note,
    'prijato' => Icons.directions_car,
    'prohlidka' => Icons.photo_camera,
    'rozpocet' => Icons.request_quote,
    'ceka_pojistovna' => Icons.hourglass_empty,
    'objednano' => Icons.shopping_cart,
    'ceka_dily' => Icons.inventory_2,
    'demontaz' => Icons.handyman,
    'klempirna' => Icons.hardware,
    'priprava_lak' => Icons.cleaning_services,
    'lakovna' => Icons.format_paint,
    'montaz' => Icons.build,
    'kontrola' => Icons.fact_check,
    'pripraveno' => Icons.key,
    'vyzvednuto' => Icons.done_all,
    _ => Icons.radio_button_checked,
  };
}

/// Barva dílenského stavu - stejná pro všechny, jako `.znacka.stav` na
/// webu. Zakázka bez stavu zůstává šedá ([AppColors.pickedUpGrey]).
Color barvaStavu(BuildContext context) =>
    context.isDarkMode ? AppColors.repairBlue : AppColors.primary;
