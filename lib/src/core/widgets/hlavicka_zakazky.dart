import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';

/// Navy hlavička obrazovky nad zakázkou (příjem, fotodokumentace) -
/// nadpis a pod ním SPZ, model a číslo zakázky, ať je jasné, u kterého
/// vozu technik je.
class HlavickaZakazky extends StatelessWidget {
  const HlavickaZakazky({
    super.key,
    required this.nadpis,
    required this.onBack,
    required this.cisloZakazky,
    this.spz,
    this.model,
  });

  final String nadpis;
  final VoidCallback onBack;
  final String cisloZakazky;
  final String? spz;
  final String? model;

  @override
  Widget build(BuildContext context) {
    final isIOS = context.isIOS;
    final podtitulek = [
      if (spz != null && spz!.isNotEmpty) spz!,
      if (model != null && model!.isNotEmpty) model!,
      cisloZakazky,
    ].join(' · ');

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.base,
        MediaQuery.paddingOf(context).top + Insets.base,
        Insets.xxl,
        Insets.xl,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zpět',
            onPressed: onBack,
            icon: Icon(
              isIOS
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: Insets.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nadpis,
                  style: AppTextStyles.appBarTitle(
                    isIOS: isIOS,
                  ).copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  podtitulek,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.appBarMeta.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
