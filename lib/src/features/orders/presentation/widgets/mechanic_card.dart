import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/service_order.dart';
import 'detail_cards.dart';

/// Kdo má zakázku na starosti + rychlý kontakt.
class MechanicCard extends StatelessWidget {
  const MechanicCard({super.key, required this.order, this.onContact});

  final ServiceOrder order;
  final VoidCallback? onContact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final advisor = order.serviceAdvisorName;

    return DetailCard(
      child: Row(
        children: [
          Container(
            width: Sizes.minTouchTarget,
            height: Sizes.minTouchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(Radii.button),
            ),
            child: Text(
              order.mechanicInitials,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.mechanicLabel,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Přiřazený mechanik · ${order.bayLabel}',
                  style: AppTextStyles.meta.copyWith(color: palette.muted),
                ),
                if (advisor != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Poradce: $advisor',
                    style: AppTextStyles.meta.copyWith(color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Semantics(
            button: true,
            label: 'Kontaktovat mechanika',
            child: GestureDetector(
              onTap: onContact,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: Sizes.minTouchTarget,
                height: Sizes.minTouchTarget,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.plate,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 19,
                  color: context.isDarkMode
                      ? AppColors.accent
                      : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
