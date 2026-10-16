import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../akce/presentation/kampane_panel.dart' show barvaKampani;
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/entities/service_order.dart';
import '../../orders/presentation/widgets/detail_cards.dart';
import 'okno_planu.dart';

/// „1 den", „3 dny", „5 dní".
String pocetDni(int n) =>
    '$n ${n == 1
        ? 'den'
        : n >= 2 && n <= 4
        ? 'dny'
        : 'dní'}';

/// Karta Klempírna / lakovna v detailu zakázky: plán, nebo tlačítko
/// k zaplánování. Jen u klempířských zakázek (nebo když plán už je).
class PlanKarta extends ConsumerWidget {
  const PlanKarta({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plan = order.planKlempirny;
    void otevri() => naplanovatKlempirnu(
      context,
      ref,
      zakazkaId: order.id,
      spz: order.licensePlate,
      plan: plan,
      barva: order.barvaVozu,
    );

    return DetailCard(
      key: const Key('plan-karta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('KLEMPÍRNA / LAKOVNA')),
              if (plan != null)
                GestureDetector(
                  key: const Key('plan-upravit'),
                  onTap: otevri,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Upravit',
                    style: AppTextStyles.cardBody.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          if (plan == null) ...[
            Text(
              'Zakázka zatím není v plánu klempírny.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.md),
            FilledButton.icon(
              key: const Key('zaplanovat-klempirnu'),
              onPressed: otevri,
              icon: const Icon(Icons.event_available_outlined, size: 20),
              label: const Text('Zaplánovat na klempírnu/lakovnu'),
            ),
          ] else
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
