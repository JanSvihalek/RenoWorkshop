import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/kampane_panel.dart' show barvaKampani;
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/entities/service_order.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../../orders/presentation/widgets/detail_cards.dart';
import 'okno_planu.dart';
import 'plan_screen.dart' show cestaPlanovace;

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

/// Barva úkonu `#RRGGBB` z číselníku; nečitelná je jako barva aplikace.
Color barvaUkonu(TypUkonu typ) {
  final hodnota = int.tryParse(typ.barva.replaceFirst('#', ''), radix: 16);
  return hodnota == null ? AppColors.accent : Color(0xFF000000 | hodnota);
}

/// Karta Klempírna / lakovna v detailu zakázky: úkony v plánu, nebo
/// zaplánování, a cesta do plánovače. U klempířských zakázek vždy, u ostatních jen
/// když plán už mají.
class PlanKarta extends ConsumerWidget {
  const PlanKarta({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plan = order.planKlempirny;
    // Plán jen s plánovačem „Plánovat" u pobočky zakázky.
    final smi = ref.watch(smiPlanovatProvider(order.branch?.code));
    void otevri({UkonPlanu? ukon}) => naplanovatKlempirnu(
      context,
      ref,
      zakazkaId: order.id,
      spz: order.licensePlate,
      plan: plan,
      ukon: ukon,
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
              if (plan != null && smi)
                GestureDetector(
                  key: const Key('plan-pridat-ukon'),
                  onTap: otevri,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Přidat úkon',
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
            if (smi) ...[
              const SizedBox(height: Insets.md),
              FilledButton.icon(
                key: const Key('zaplanovat-klempirnu'),
                onPressed: otevri,
                icon: const Icon(Icons.event_available_outlined, size: 20),
                label: const Text('Zaplánovat na klempírnu/lakovnu'),
              ),
            ],
          ] else
            _Plan(
              plan: plan,
              kodLaku: kodLakuZakazky(plan, order.barvaVozu),
              onUkon: smi ? (ukon) => otevri(ukon: ukon) : null,
            ),
          if (ref.watch(vidiPlanovacProvider)) ...[
            const SizedBox(height: Insets.sm),
            TextButton.icon(
              key: const Key('otevrit-planovac'),
              onPressed: () => context.push(cestaPlanovace),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Otevřít plánovač'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.plan, required this.kodLaku, this.onUkon});

  final PlanKlempirny plan;
  final String? kodLaku;

  /// Bez něj (jen čtení) úkony nejde otevřít k úpravě.
  final ValueChanged<UkonPlanu>? onUkon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              obdobiPlanu(plan.od, plan.do_),
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (kodLaku != null) KodLaku(kod: kodLaku!),
          ],
        ),
        for (final ukon in plan.ukony) ...[
          const SizedBox(height: Insets.sm),
          _Ukon(ukon: ukon, onTap: onUkon == null ? null : () => onUkon!(ukon)),
        ],
      ],
    );
  }
}

/// Jeden úkon v kartě: proužek v barvě typu, dny, stav a poznámka.
class _Ukon extends StatelessWidget {
  const _Ukon({required this.ukon, this.onTap});

  final UkonPlanu ukon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      key: Key('plan-ukon-${ukon.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        decoration: BoxDecoration(
          color: barvaUkonu(ukon.typ).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: barvaUkonu(ukon.typ), width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  ukon.typ.nazev,
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                StavPlanuZnacka(hotovo: ukon.hotovo),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${obdobiPlanu(ukon.od, ukon.do_)} · ${pocetDni(ukon.dni)}',
              style: AppTextStyles.metaSmall.copyWith(color: palette.text),
            ),
            if (ukon.poznamka.trim().isNotEmpty) ...[
              const SizedBox(height: Insets.xs),
              Text(
                ukon.poznamka,
                style: AppTextStyles.noteText.copyWith(color: palette.text),
              ),
            ],
            if (ukon.zaplanoval != null) ...[
              const SizedBox(height: Insets.xs),
              Text(
                'Zaplánoval ${ukon.zaplanoval}',
                style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
              ),
            ],
          ],
        ),
      ),
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
