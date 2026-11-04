import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/presentation/widgets/plate_chip.dart';
import '../../domain/entities/vozidlo.dart';

/// Vůz z evidence v seznamu - klepnutím karta vozu přes celou obrazovku.
class RadekVozidla extends StatelessWidget {
  const RadekVozidla({super.key, required this.vozidlo, required this.onTap});

  final NalezeneVozidlo vozidlo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Vozidlo ${vozidlo.spz}',
      child: GestureDetector(
        key: Key('vozidlo-${vozidlo.id}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vozidlo.spz.isNotEmpty)
                      PlateChip(licensePlate: vozidlo.spz),
                    const SizedBox(height: Insets.sm),
                    Text(
                      vozidlo.model.isEmpty ? 'Neznámý model' : vozidlo.model,
                      style: AppTextStyles.cardModel.copyWith(
                        color: palette.text,
                      ),
                    ),
                    if (vozidlo.majitel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        vozidlo.majitel!,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                    if (vozidlo.vin.isNotEmpty) ...[
                      const SizedBox(height: Insets.xxs),
                      Text(
                        vozidlo.vin,
                        style: AppTextStyles.monoLabel.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Insets.base),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _zakazek(vozidlo.pocetZakazek),
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Icon(Icons.chevron_right_rounded, color: palette.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _zakazek(int pocet) => switch (pocet) {
    0 => 'bez zakázek',
    1 => '1 zakázka',
    >= 2 && <= 4 => '$pocet zakázky',
    _ => '$pocet zakázek',
  };
}
