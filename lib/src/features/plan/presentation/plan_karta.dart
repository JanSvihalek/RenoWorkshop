import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/kampane_panel.dart' show barvaKampani;
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/entities/service_order.dart';
import '../../orders/presentation/widgets/detail_cards.dart';

/// „12. 10. – 14. 10. 2026", přes rok s rokem u obou.
String obdobiPlanu(DateTime od, DateTime do_) {
  final zacatek = od.year == do_.year
      ? AppDateFormat.dayMonth(od)
      : AppDateFormat.date(od);
  return '$zacatek – ${AppDateFormat.date(do_)}';
}

/// „1 den", „3 dny", „5 dní".
String pocetDni(int n) =>
    '$n ${n == 1
        ? 'den'
        : n >= 2 && n <= 4
        ? 'dny'
        : 'dní'}';

/// Karta Klempírna / lakovna v detailu zakázky - jen ke čtení. Plánuje
/// se v portálu plánu na PC (`/plan/`), dílna tu vidí, kdy a s jakým
/// kódem laku vůz na klempírnu jde. Jen u zakázky, která plán má.
class PlanKarta extends StatelessWidget {
  const PlanKarta({super.key, required this.order, required this.plan});

  final ServiceOrder order;
  final PlanKlempirny plan;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      key: const Key('plan-karta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('KLEMPÍRNA / LAKOVNA'),
          const SizedBox(height: Insets.sm),
          _Plan(plan: plan, kodLaku: kodLakuZakazky(plan, order.barvaVozu)),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.plan, required this.kodLaku});

  final PlanKlempirny plan;
  final String? kodLaku;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${obdobiPlanu(plan.od, plan.do_)} · ${pocetDni(plan.dni)}',
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            StavPlanuZnacka(hotovo: plan.hotovo),
            if (kodLaku != null) KodLaku(kod: kodLaku!),
          ],
        ),
        if (plan.poznamka.trim().isNotEmpty) ...[
          const SizedBox(height: Insets.sm),
          Text(
            plan.poznamka,
            style: AppTextStyles.noteText.copyWith(color: palette.text),
          ),
        ],
        if (plan.zaplanoval != null) ...[
          const SizedBox(height: Insets.xs),
          Text(
            'Zaplánoval ${plan.zaplanoval}',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}

/// Naplánováno / Hotovo.
class StavPlanuZnacka extends StatelessWidget {
  const StavPlanuZnacka({super.key, required this.hotovo});

  final bool hotovo;

  @override
  Widget build(BuildContext context) {
    final barva = hotovo ? AppColors.readyGreen : barvaKampani(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: barva.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: barva.withValues(alpha: 0.5)),
      ),
      child: Text(
        hotovo ? 'HOTOVO' : 'NAPLÁNOVÁNO',
        style: AppTextStyles.overline.copyWith(
          fontSize: 10,
          color: barva,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// „KÓD 416" - kód laku jako štítek.
class KodLaku extends StatelessWidget {
  const KodLaku({super.key, required this.kod, this.naPruhu = false});

  final String kod;

  /// Na barevném pruhu v plánu - bílý podklad.
  final bool naPruhu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: naPruhu ? Colors.white : palette.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'KÓD ',
              style: AppTextStyles.overline.copyWith(
                fontSize: 9.5,
                color: naPruhu ? const Color(0xFF4A5568) : palette.muted,
              ),
            ),
            TextSpan(
              text: kod,
              style: AppTextStyles.metaSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: naPruhu ? const Color(0xFF1A2233) : palette.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
