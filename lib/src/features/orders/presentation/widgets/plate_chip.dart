import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

/// SPZ v monospace na "plechu" - kvůli rychlému skenování na dílně.
class PlateChip extends StatelessWidget {
  const PlateChip({super.key, required this.licensePlate});

  final String licensePlate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.plate,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: palette.hairline),
      ),
      child: Text(
        licensePlate,
        style: AppTextStyles.plateChip.copyWith(color: palette.text),
      ),
    );
  }
}

/// SPZ jako značka: bílá s modrým pruhem bez země (může být i zahraniční),
/// stejná i v tmavém vzhledu.
class SpzRamecek extends StatelessWidget {
  const SpzRamecek({super.key, required this.licensePlate, this.maly = false});

  final String licensePlate;

  /// Menší velikost pro kartu v přehledu zakázek.
  final bool maly;

  /// Modrá pruhu na značce.
  static const _modra = Color(0xFF003399);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(maly ? 5 : 6),
        border: Border.all(color: AppColors.primary, width: maly ? 1.5 : 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: maly ? 8 : 12, color: _modra),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: maly ? 7 : 9,
                vertical: maly ? 2 : 4,
              ),
              child: Text(
                licensePlate,
                maxLines: 1,
                softWrap: false,
                style: AppTextStyles.plateLarge.copyWith(
                  fontSize: maly ? 15 : 22,
                  height: 1.15,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
