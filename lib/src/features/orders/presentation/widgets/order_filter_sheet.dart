import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/order_filter.dart';
import '../controllers/orders_providers.dart';

/// Řazení + doplňkové filtry (mechanik, uzavřené zakázky).
/// Pobočka a stav se filtrují přímo v hlavičce seznamu.
class OrderFilterSheet extends ConsumerWidget {
  const OrderFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const OrderFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final filter = ref.watch(orderFilterProvider);
    final controller = ref.read(orderFilterProvider.notifier);
    final mechanics = ref.watch(mechanicsProvider);
    final departments = ref.watch(availableDepartmentsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.xxl,
          0,
          Insets.xxl,
          Insets.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Zobrazení seznamu',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 17,
                      color: palette.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    controller.reset();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Zrušit filtry'),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            _SheetLabel('ŘADIT PODLE'),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final sort in OrderSort.values)
                  _SheetChip(
                    label: sort.label,
                    isSelected: filter.sort == sort,
                    onTap: () => controller.setSort(sort),
                  ),
              ],
            ),
            // Útvar je jemnější dělení než pobočka v app baru; seznam se
            // zužuje podle právě vybrané pobočky, ať v něm není nepořádek.
            if (departments.length > 1) ...[
              const SizedBox(height: Insets.xxl),
              _SheetLabel('ÚTVAR'),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  _SheetChip(
                    label: 'Všechny',
                    isSelected: filter.departmentCode == null,
                    onTap: () => controller.setDepartment(null),
                  ),
                  for (final department in departments)
                    _SheetChip(
                      label: department.label,
                      isSelected: filter.departmentCode == department.code,
                      onTap: () => controller.setDepartment(department.code),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Insets.xxl),
            _SheetLabel('MECHANIK'),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                _SheetChip(
                  label: 'Všichni',
                  isSelected: filter.mechanicName == null,
                  onTap: () => controller.setMechanic(null),
                ),
                for (final mechanic in mechanics)
                  _SheetChip(
                    label: mechanic,
                    isSelected: filter.mechanicName == mechanic,
                    onTap: () => controller.setMechanic(mechanic),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: !filter.includeClosed,
              onChanged: (hideClosed) =>
                  controller.setIncludeClosed(!hideClosed),
              title: Text(
                'Skrýt vyzvednuté zakázky',
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 14.5,
                  color: palette.text,
                ),
              ),
              subtitle: Text(
                'Zobrazí jen vozidla, která jsou ještě na dílně.',
                style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.overline.copyWith(color: context.palette.muted),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : palette.background,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(
            color: isSelected ? AppColors.primary : palette.hairline2,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            color: isSelected ? Colors.white : palette.muted2,
          ),
        ),
      ),
    );
  }
}
