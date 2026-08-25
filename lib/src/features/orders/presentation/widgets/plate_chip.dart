import 'package:flutter/material.dart';

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
