import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/dilensky_stav.dart';
import 'order_status_visuals.dart';

/// Dílenské stavy - co se na zakázce dělo.
///
/// Není to sled předem daných kroků, ale **historie toho, co kdo zapsal**.
/// U opravy po bouračce, která běží měsíce, je hlavní informace právě to,
/// kdy se co stalo a jak dlouho se na co čekalo.
///
/// Nejnovější je nahoře. Aktuální stav má výraznou ikonu kroku, starší šedé
/// řádky s malou fajfkou - barvu nese jen to, na co se dá klepnout.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.historie,
    required this.bay,
    this.onSmazat,
    this.sAktualnim = true,
  });

  final List<DilenskyStav> historie;

  /// Je první záznam aktuální stav? `false` u sbalené historie, kde jsou
  /// jen starší.
  final bool sAktualnim;

  /// Stání / box, kde vozidlo právě stojí (meta u aktuálního stavu).
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
          Padding(
            padding: EdgeInsets.only(
              bottom: index == historie.length - 1 ? 0 : Insets.base,
            ),
            child: _Radek(
              stav: historie[index],
              // Platný je poslední zapsaný, tedy ten nahoře.
              jeAktualni: sAktualnim && index == 0,
              bay: bay,
              onSmazat: onSmazat,
            ),
          ),
      ],
    );
  }
}

class _Radek extends StatelessWidget {
  const _Radek({
    required this.stav,
    required this.jeAktualni,
    required this.bay,
    required this.onSmazat,
  });

  final DilenskyStav stav;
  final bool jeAktualni;
  final String bay;
  final void Function(DilenskyStav stav)? onSmazat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (jeAktualni)
          Container(
            key: const Key('stav-ikona'),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.hairline),
            ),
            child: Icon(stav.ikonaKroku, size: 22, color: palette.text),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check, size: 16, color: palette.muted),
          ),
        SizedBox(width: jeAktualni ? Insets.base : Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stav.nazev,
                      style: AppTextStyles.cardBody.copyWith(
                        color: jeAktualni ? palette.text : palette.muted2,
                        fontWeight: jeAktualni
                            ? FontWeight.w700
                            : FontWeight.w500,
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
                  style: AppTextStyles.cardBody.copyWith(color: palette.muted2),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                _popisek(),
                style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ],
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
