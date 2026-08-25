import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';

/// Bílá karta v detailu zakázky - společný podklad pro všechny sekce.
class DetailCard extends StatelessWidget {
  const DetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.xl),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
      ),
      child: child,
    );
  }
}

/// Nadpis sekce ("POSTUP ZAKÁZKY").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.overline.copyWith(color: context.palette.muted),
    );
  }
}

/// Info box s jedním údajem - "PŘIJATO", "TERMÍN DOKONČENÍ".
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DetailCard(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppTextStyles.dataValue.copyWith(
              color: valueColor ?? palette.text,
            ),
          ),
        ],
      ),
    );
  }
}
