import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/order_status.dart';
import 'order_status_visuals.dart';

/// Svislá časová osa postupu zakázky - všech 7 stavů, aktuální zvýrazněný.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.status, required this.bay});

  final OrderStatus status;

  /// Stání / box, kde vozidlo právě stojí (meta u aktuálního kroku).
  final String bay;

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.values;

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineRow(
            step: steps[index],
            isDone: index < status.step,
            isCurrent: index == status.step,
            isLast: index == steps.length - 1,
            bay: bay,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    required this.bay,
  });

  final OrderStatus step;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  final String bay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final doneColor = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : AppColors.neutralLight;

    final meta = isCurrent
        ? 'Aktuální stav · $bay'
        : (isDone ? 'Dokončeno' : 'Nezahájeno');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: Sizes.timelineDot,
            child: Column(
              children: [
                _Dot(
                  step: step,
                  isDone: isDone,
                  isCurrent: isCurrent,
                  doneColor: doneColor,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: Insets.lg),
                      color: isDone ? doneColor : palette.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: isCurrent ? 15.5 : 14.5,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.15,
                      color: isCurrent
                          ? palette.text
                          : (isDone ? palette.muted2 : palette.muted),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrent ? step.color : palette.muted,
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
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.step,
    required this.isDone,
    required this.isCurrent,
    required this.doneColor,
  });

  final OrderStatus step;
  final bool isDone;
  final bool isCurrent;
  final Color doneColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: Sizes.timelineDot,
      height: Sizes.timelineDot,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent
            ? step.color
            : (isDone ? doneColor : Colors.transparent),
        border: isCurrent
            ? Border.all(color: step.color, width: 3)
            : (isDone
                  ? null
                  : Border.all(color: palette.hairline2, width: 2)),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: step.color.withValues(alpha: 0.18),
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: isDone
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}
