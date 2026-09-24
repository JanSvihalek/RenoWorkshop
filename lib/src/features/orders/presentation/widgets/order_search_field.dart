import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';

/// Fulltext nad SPZ, zákazníkem, číslem zakázky a modelem.
/// Debounce drží volající (v produkci šetří dotazy na server).
class OrderSearchField extends StatelessWidget {
  const OrderSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.onScan,
    this.hintText = 'SPZ, zákazník, číslo zakázky',
    this.naTmavem = true,
  });

  final TextEditingController controller;

  /// Kvůli „Zadat ručně" ve skeneru - pole si po jeho zavření vezme fokus.
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;

  /// Načtení VINu nebo SPZ fotoaparátem. Když chybí, ikona se nezobrazí.
  final VoidCallback? onScan;

  /// Co pole hledá - seznam zakázek hledá širší, vozidla jen SPZ a VIN.
  final String hintText;

  /// Pole leží na tmavomodré hlavičce (telefon), nebo na šedém podkladu
  /// seznamu (tablet). Na světlém podkladu by bílý text a průsvitné pole
  /// zmizely, proto se barvy obracejí.
  final bool naTmavem;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = naTmavem ? Colors.white : palette.text;
    final tlumeny = naTmavem
        ? Colors.white.withValues(alpha: 0.6)
        : palette.muted;

    return Container(
      height: Sizes.searchFieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: naTmavem ? Colors.white.withValues(alpha: 0.13) : palette.card,
        borderRadius: BorderRadius.circular(Radii.input),
        border: naTmavem ? null : Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: tlumeny),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              focusNode: focusNode,
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: text,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14.5,
                color: text,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 14.5,
                  color: tlumeny,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(Icons.close_rounded, size: 18, color: tlumeny),
            ),
          // VIN se z rámu opisuje mizerně, tak ať ho jde vyfotit.
          if (onScan != null) ...[
            const SizedBox(width: Insets.base),
            Semantics(
              button: true,
              label: 'Načíst VIN nebo SPZ fotoaparátem',
              child: GestureDetector(
                onTap: onScan,
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 20,
                  color: naTmavem
                      ? Colors.white.withValues(alpha: 0.75)
                      : palette.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
