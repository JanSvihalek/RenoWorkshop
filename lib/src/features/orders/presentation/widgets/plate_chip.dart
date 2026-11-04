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

/// SPZ jako značka: bílá s modrým pruhem CZ, stejná i v tmavém vzhledu.
class SpzRamecek extends StatelessWidget {
  const SpzRamecek({super.key, required this.licensePlate});

  final String licensePlate;

  /// Modrá pruhu na české značce.
  static const _modra = Color(0xFF003399);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 18,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 3),
                color: _modra,
                child: const Text(
                  'CZ',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Text(
                licensePlate,
                maxLines: 1,
                softWrap: false,
                style: AppTextStyles.plateLarge.copyWith(
                  fontSize: 22,
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
