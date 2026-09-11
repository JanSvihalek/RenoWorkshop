import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/dilensky_stav.dart';

/// Vodorovná řada filtrů stavů pod app barem. `null` = všechny stavy.
///
/// Nabízí jen stavy, které jsou v načtených zakázkách - číselník jich může
/// mít dvacet, ale filtrovat podle stavu, který na dílně nikdo nemá, nemá
/// smysl. Řada se vodorovně posouvá.
class StatusFilterChips extends StatelessWidget {
  const StatusFilterChips({
    super.key,
    required this.stavy,
    required this.selected,
    required this.onChanged,
  });

  final List<DilenskyStav> stavy;

  /// Kód vybraného stavu.
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final options = <(String?, String)>[
      (null, 'Všechny stavy'),
      for (final stav in stavy) (stav.kod, stav.nazev),
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xxl,
          vertical: Insets.base,
        ),
        child: Row(
          children: [
            for (final (kod, label) in options) ...[
              _FilterChip(
                label: label,
                isSelected: selected == kod,
                onTap: () => onChanged(kod),
              ),
              if (kod != options.last.$1) const SizedBox(width: Insets.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : palette.card),
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
      ),
    );
  }
}
