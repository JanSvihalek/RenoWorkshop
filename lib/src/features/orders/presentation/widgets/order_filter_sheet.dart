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
    final typy = ref.watch(availableOrderTypesProvider);

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
            // Typ zakázky přijde z Heliosu; dokud ho pohled nedotahuje,
            // sekce se vůbec nezobrazí.
            if (typy.length > 1) ...[
              const SizedBox(height: Insets.xxl),
              _SheetLabel('TYP ZAKÁZKY'),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  _SheetChip(
                    label: 'Všechny',
                    isSelected: filter.typZakazkyKod == null,
                    onTap: () => controller.setTypZakazky(null),
                  ),
                  for (final typ in typy)
                    _SheetChip(
                      label: typ.nazev,
                      isSelected: filter.typZakazkyKod == typ.kod,
                      onTap: () => controller.setTypZakazky(typ.kod),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Insets.xxl),
            // Rozbalovací seznam, ne chipy: zodpovědných osob jsou desítky
            // a jako řada štítků z panelu udělaly nečitelnou zeď.
            _SheetLabel('ZODPOVÍDÁ'),
            const SizedBox(height: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(color: palette.hairline2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: mechanics.contains(filter.mechanicName)
                      ? filter.mechanicName
                      : null,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(Radii.input),
                  style: AppTextStyles.chip.copyWith(color: palette.text),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Všichni')),
                    for (final mechanic in mechanics)
                      DropdownMenuItem(value: mechanic, child: Text(mechanic)),
                  ],
                  onChanged: controller.setMechanic,
                ),
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
        // Jména mechaniků i názvy řad zakázek můžou být dlouhá. Wrap sice
        // přeteklý štítek přesune na další řádek, ale nezúží ho - přes
        // šířku panelu by se roztáhl.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 2 * Insets.xxl,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : palette.background,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(
            color: isSelected ? AppColors.primary : palette.hairline2,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.chip.copyWith(
            color: isSelected ? Colors.white : palette.muted2,
          ),
        ),
      ),
    );
  }
}
