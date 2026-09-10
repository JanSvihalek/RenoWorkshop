import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/branch.dart';

/// Výběr útvaru v app baru. `null` = všechny útvary.
///
/// Rozbalovací seznam, ne řada přepínačů: útvarů je napříč pobočkami
/// mnohem víc než poboček a do řádku by se nevešly.
///
/// Nabídka se skládá z toho, co je v načtených zakázkách, takže nový útvar
/// v Heliosu se objeví sám, bez nové verze aplikace. Útvary se zobrazují
/// kódem (`11211`) - viz `ServiceOrder.departmentLabel`.
class DepartmentPicker extends StatelessWidget {
  const DepartmentPicker({
    super.key,
    required this.departments,
    required this.selectedCode,
    required this.onChanged,
  });

  final List<Department> departments;
  final String? selectedCode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Uložený útvar, který v datech není (jiná pobočka, uzavřené zakázky),
    // by shodil DropdownButton na neexistující hodnotě.
    final znamy = departments.any((utvar) => utvar.code == selectedCode);

    return Container(
      height: Sizes.searchFieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: Insets.base),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 18, color: Colors.white70),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: znamy ? selectedCode : null,
                isExpanded: true,
                isDense: true,
                dropdownColor: palette.card,
                borderRadius: BorderRadius.circular(Radii.input),
                icon: const Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white70,
                ),
                style: AppTextStyles.cardBody.copyWith(color: palette.text),
                selectedItemBuilder: (context) => [
                  _vybrany('Všechny útvary'),
                  for (final utvar in departments) _vybrany(utvar.code),
                ],
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      'Všechny útvary',
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                      ),
                    ),
                  ),
                  for (final utvar in departments)
                    DropdownMenuItem(
                      value: utvar.code,
                      child: Text(
                        utvar.label == utvar.code
                            ? utvar.code
                            : '${utvar.code} · ${utvar.label}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.text,
                        ),
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Zavřený seznam leží na tmavém app baru, rozbalený na světlé kartě -
  /// vybraná položka proto potřebuje jinou barvu než položky v nabídce.
  Widget _vybrany(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.cardBody.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
