import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/branch.dart';

/// Přepínač poboček v app baru. `null` = všechny pobočky.
class BranchSegmentedControl extends StatelessWidget {
  const BranchSegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Branch? selected;
  final ValueChanged<Branch?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(Branch?, String)>[
      (null, 'Vše'),
      for (final branch in Branch.values) (branch, branch.label),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (branch, label) in options)
            Expanded(
              child: _Segment(
                label: label,
                isSelected: selected == branch,
                onTap: () => onChanged(branch),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ),
      ),
    );
  }
}
