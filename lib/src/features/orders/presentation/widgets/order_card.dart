import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/service_order.dart';
import 'plate_chip.dart';
import 'status_badge.dart';

/// Karta zakázky v seznamu. Jeden tap = detail.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final ServiceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final overdue = order.isOverdue();

    return _PressableCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: Insets.lg),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: palette.hairline),
          boxShadow: palette.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.id,
                    style: AppTextStyles.orderNumber.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ),
                StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 9,
              runSpacing: 6,
              children: [
                PlateChip(licensePlate: order.licensePlate),
                Text(
                  order.model,
                  style: AppTextStyles.cardModel.copyWith(color: palette.text),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              order.customerName,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted2),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _MechanicAvatar(initials: order.mechanicInitials),
                const SizedBox(width: Insets.sm),
                Flexible(
                  child: Text(
                    order.mechanicLabel,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta.copyWith(color: palette.muted),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: palette.muted.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  order.branch.label,
                  style: AppTextStyles.meta.copyWith(color: palette.muted),
                ),
                const Spacer(),
                if (overdue) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  AppDateFormat.dayMonth(order.dueAt),
                  style: AppTextStyles.orderNumber.copyWith(
                    fontSize: 12.5,
                    color: overdue ? AppColors.danger : palette.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MechanicAvatar extends StatelessWidget {
  const _MechanicAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.avatar, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: palette.muted2,
        ),
      ),
    );
  }
}

/// Tap feedback z návrhu: krátké scale(.994) místo Material ripplu -
/// stejné chování na iOS i Androidu.
class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.994 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
