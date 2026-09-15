import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../domain/entities/prijem.dart';
import '../controllers/prijem_providers.dart';

/// Karta Příjem vozidla v detailu zakázky - jestli příjem proběhl, kdo ho
/// dokončil a kolik kontrol má poznámku. Klepnutím se otevře checklist.
class PrijemKarta extends ConsumerWidget {
  const PrijemKarta({
    super.key,
    required this.orderId,
    required this.onOtevrit,
  });

  final String orderId;
  final VoidCallback onOtevrit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prijem = ref.watch(prijemZakazkyProvider(orderId));

    final (String popis, IconData ikona, Color barva) = switch (prijem) {
      AsyncData(:final value) => switch (value.stav) {
        StavPrijmu.nezahajen => (
          'Nezahájen',
          Icons.fact_check_outlined,
          AppColors.accent,
        ),
        StavPrijmu.rozpracovany => (
          'Rozpracovaný · zkontrolováno '
              '${value.pocetVyplnenych} z ${value.pocetPovinnych}',
          Icons.pending_actions_rounded,
          AppColors.repairBlue,
        ),
        StavPrijmu.dokoncen => (
          [
            'Dokončen',
            if (value.dokoncenoAt != null)
              AppDateFormat.date(value.dokoncenoAt!),
            if (value.dokoncilKdo != null) value.dokoncilKdo!,
          ].join(' · '),
          Icons.task_alt_rounded,
          AppColors.readyGreen,
        ),
      },
      AsyncError() => (
        'Příjem se nepodařilo načíst.',
        Icons.cloud_off_rounded,
        palette.muted,
      ),
      _ => ('Načítám příjem…', Icons.fact_check_outlined, palette.muted),
    };
    final poznamek = prijem.valueOrNull?.pocetPoznamek ?? 0;

    return Semantics(
      button: true,
      label: 'Otevřít příjem vozidla',
      child: GestureDetector(
        key: const Key('otevrit-prijem'),
        onTap: onOtevrit,
        behavior: HitTestBehavior.opaque,
        child: DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionLabel('PŘÍJEM VOZIDLA')),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: palette.muted,
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Icon(ikona, size: 20, color: barva),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      popis,
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                      ),
                    ),
                  ),
                ],
              ),
              // Poznámky jsou nálezy z kontroly - ty má vidět každý, kdo
              // zakázku otevře, ne jen ten, kdo příjem dělal.
              if (poznamek > 0) ...[
                const SizedBox(height: Insets.xs),
                Text(
                  poznamek == 1
                      ? '1 kontrola s poznámkou'
                      : '$poznamek kontrol s poznámkou',
                  style: AppTextStyles.metaSmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
