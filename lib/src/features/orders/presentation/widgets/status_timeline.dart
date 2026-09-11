import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/dilensky_stav.dart';
import 'order_status_visuals.dart';

/// Svislá časová osa dílenských stavů — co se na zakázce dělo.
///
/// Není to sled předem daných kroků, ale **historie toho, co kdo zapsal**.
/// U opravy po bouračce, která běží měsíce, je hlavní informace právě to,
/// kdy se co stalo a jak dlouho se na co čekalo.
///
/// Nejnovější je nahoře.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.historie,
    required this.bay,
    this.onSmazat,
  });

  final List<DilenskyStav> historie;

  /// Stání / box, kde vozidlo právě stojí (meta u posledního kroku).
  final String bay;

  /// Smaže záznam. `null` schová mazání úplně.
  final void Function(DilenskyStav stav)? onSmazat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (historie.isEmpty) {
      return Text(
        'Zakázka zatím nemá žádný dílenský stav. Přidejte první tlačítkem výš.',
        style: AppTextStyles.cardBody.copyWith(color: palette.muted),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < historie.length; index++)
          _TimelineRow(
            stav: historie[index],
            // Platný je poslední zapsaný, tedy ten nahoře.
            jeAktualni: index == 0,
            jePosledniVSeznamu: index == historie.length - 1,
            bay: bay,
            onSmazat: onSmazat,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.stav,
    required this.jeAktualni,
    required this.jePosledniVSeznamu,
    required this.bay,
    required this.onSmazat,
  });

  final DilenskyStav stav;
  final bool jeAktualni;
  final bool jePosledniVSeznamu;
  final String bay;
  final void Function(DilenskyStav stav)? onSmazat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barva = jeAktualni ? stav.color : palette.muted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: Sizes.timelineDot,
                height: Sizes.timelineDot,
                decoration: BoxDecoration(
                  color: jeAktualni ? barva : Colors.transparent,
                  border: Border.all(color: barva, width: 2),
                  shape: BoxShape.circle,
                ),
                child: jeAktualni
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!jePosledniVSeznamu)
                Expanded(
                  child: Container(
                    width: 2,
                    color: palette.hairline2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: Insets.base),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: jePosledniVSeznamu ? 0 : Insets.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stav.nazev,
                          style: AppTextStyles.cardBody.copyWith(
                            color: palette.text,
                            fontWeight: jeAktualni
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      // Mazání jen u záznamů, které prošly serverem -
                      // bez id není co smazat.
                      if (onSmazat != null && stav.id != null)
                        GestureDetector(
                          onTap: () => onSmazat!(stav),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: Insets.sm),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Co k tomu kroku patří - kde vůz stojí, na co se čeká.
                  if (stav.poznamka != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      stav.poznamka!,
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.muted2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _popisek(),
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kdy a kdo — u aktuálního stavu i stání, pokud je vyplněné.
  String _popisek() {
    final casti = <String>[
      if (stav.zadano != null) AppDateFormat.dateTime(stav.zadano!),
      if (stav.autor != null) stav.autor!,
      if (jeAktualni && bay.isNotEmpty) bay,
    ];
    return casti.isEmpty ? '—' : casti.join(' · ');
  }
}
