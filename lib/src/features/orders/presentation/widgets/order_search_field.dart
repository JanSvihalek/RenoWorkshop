import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';

/// Fulltext nad SPZ, zákazníkem, číslem zakázky a modelem.
/// Debounce drží volající (v produkci šetří dotazy na server).
class OrderSearchField extends StatelessWidget {
  const OrderSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onScan,
    this.hintText = 'SPZ, zákazník, číslo zakázky',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Načtení VINu nebo SPZ fotoaparátem. Když chybí, ikona se nezobrazí.
  final VoidCallback? onScan;

  /// Co pole hledá - seznam zakázek hledá širší, vozidla jen SPZ a VIN.
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Sizes.searchFieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 18,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: Colors.white,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14.5,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 14.5,
                  color: Colors.white.withValues(alpha: 0.55),
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
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
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
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
