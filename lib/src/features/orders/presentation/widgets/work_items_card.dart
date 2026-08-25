import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/work_item.dart';
import 'detail_cards.dart';

/// Provedené a plánované úkony na zakázce.
/// Odbavení úkonu je zápis do stejné vrstvy jako posun stavu.
class WorkItemsCard extends StatelessWidget {
  const WorkItemsCard({
    super.key,
    required this.items,
    required this.onToggle,
    this.isBusy = false,
  });

  final List<WorkItem> items;
  final void Function(WorkItem item, bool isDone) onToggle;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final done = items.where((item) => item.isDone).length;
    final hours = items.fold<double>(
      0,
      (sum, item) => sum + (item.estimatedHours ?? 0),
    );

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('ÚKONY NA ZAKÁZCE')),
              Text(
                '$done/${items.length} · ${hours.toStringAsFixed(1)} h',
                style: AppTextStyles.orderNumber.copyWith(
                  fontSize: 11.5,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.base),
          if (items.isEmpty)
            Text(
              'Zatím žádné úkony.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          for (final item in items)
            _WorkItemRow(
              item: item,
              onToggle: isBusy ? null : (value) => onToggle(item, value),
            ),
        ],
      ),
    );
  }
}

class _WorkItemRow extends StatelessWidget {
  const _WorkItemRow({required this.item, required this.onToggle});

  final WorkItem item;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = context.isDarkMode ? AppColors.accent : AppColors.primary;

    return Semantics(
      button: true,
      checked: item.isDone,
      child: GestureDetector(
        onTap: onToggle == null ? null : () => onToggle!(!item.isDone),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.isDone ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isDone ? accent : palette.hairline2,
                    width: 2,
                  ),
                ),
                child: item.isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.title,
                  style: AppTextStyles.noteText.copyWith(
                    color: item.isDone ? palette.muted : palette.text,
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: palette.muted,
                  ),
                ),
              ),
              if (item.estimatedHours != null) ...[
                const SizedBox(width: Insets.sm),
                Text(
                  '${item.estimatedHours!.toStringAsFixed(1)} h',
                  style: AppTextStyles.orderNumber.copyWith(
                    fontSize: 11.5,
                    color: palette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
