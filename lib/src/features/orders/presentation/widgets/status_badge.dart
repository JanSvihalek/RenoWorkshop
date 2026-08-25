import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/order_status.dart';
import 'order_status_visuals.dart';

/// Badge stavu zakázky - plná výplň barvou stavu, bílý text.
/// Plná výplň je záměr: musí být čitelná na dálku a v rukavicích.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.fontSize = 11.5});

  final OrderStatus status;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(Radii.badge),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.badge.copyWith(
          fontSize: fontSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
