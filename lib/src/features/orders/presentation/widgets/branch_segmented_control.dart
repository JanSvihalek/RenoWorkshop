import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/branch.dart';

/// Přepínač poboček v app baru. `null` = všechny pobočky.
///
/// Pobočky nejsou pevný seznam - skládají se z toho, co je v datech, takže
/// nová pobočka v Heliosu se objeví sama, bez nové verze appky. Když jich
/// je moc, řádek se vodorovně posouvá; jemnější dělení na útvary je ve
/// filtrovacím panelu.
class BranchSegmentedControl extends StatelessWidget {
  const BranchSegmentedControl({
    super.key,
    required this.branches,
    required this.selectedCode,
    required this.onChanged,
  });

  /// Pobočky, které se vyskytují v načtených zakázkách.
  final List<Branch> branches;

  final String? selectedCode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(String?, String)>[
      (null, 'Vše'),
      for (final branch in branches) (branch.code, branch.label),
    ];

    // Do čtyř položek se vejde rovnoměrné dělení, víc už se musí posouvat.
    if (options.length > 4) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              for (final (code, label) in options)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Segment(
                    label: label,
                    isSelected: selectedCode == code,
                    onTap: () => onChanged(code),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (code, label) in options)
            Expanded(
              child: _Segment(
                label: label,
                isSelected: selectedCode == code,
                onTap: () => onChanged(code),
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
