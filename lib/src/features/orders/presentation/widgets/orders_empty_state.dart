import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';

/// Prázdný výsledek filtru - nabídne rovnou reset.
class OrdersEmptyState extends StatelessWidget {
  const OrdersEmptyState({super.key, required this.onResetFilters});

  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 60, left: 30, right: 30),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.hairline2,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Text(
              '0',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 20,
                color: palette.muted,
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            'Žádná zakázka nevyhovuje',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Zkuste jinou pobočku nebo stav, případně smažte hledaný text.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardBody.copyWith(
              color: palette.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Insets.xl),
          SizedBox(
            height: Sizes.minTouchTarget,
            child: FilledButton(
              onPressed: onResetFilters,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.chip + 1),
                ),
              ),
              child: const Text('Zrušit filtry'),
            ),
          ),
        ],
      ),
    );
  }
}
