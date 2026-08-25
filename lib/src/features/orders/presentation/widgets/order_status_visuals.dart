import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/order_status.dart';

/// Vizuální mapování stavu zakázky.
///
/// Doména ([OrderStatus]) zůstává bez závislosti na Flutteru - barvy a ikony
/// žijí až v prezentační vrstvě.
extension OrderStatusVisuals on OrderStatus {
  Color get color => switch (this) {
    OrderStatus.received => AppColors.ink,
    OrderStatus.diagnostics => AppColors.accent,
    OrderStatus.waitingForParts => AppColors.danger,
    OrderStatus.inRepair => AppColors.repairBlue,
    OrderStatus.qualityCheck => AppColors.qualityBlue,
    OrderStatus.readyForPickup => AppColors.readyGreen,
    OrderStatus.pickedUp => AppColors.pickedUpGrey,
  };

  IconData get icon => switch (this) {
    OrderStatus.received => Icons.inbox_outlined,
    OrderStatus.diagnostics => Icons.troubleshoot_outlined,
    OrderStatus.waitingForParts => Icons.inventory_2_outlined,
    OrderStatus.inRepair => Icons.build_outlined,
    OrderStatus.qualityCheck => Icons.fact_check_outlined,
    OrderStatus.readyForPickup => Icons.task_alt_outlined,
    OrderStatus.pickedUp => Icons.directions_car_outlined,
  };
}
