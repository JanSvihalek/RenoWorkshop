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
import '../../orders/presentation/widgets/pridat_stav_sheet.dart';
import '../domain/prehled_planu.dart';
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

/// Plán v kartě Průběh opravy: úkony s tím, co s nimi je, a cesta do
/// plánovače. Plán říká, co se má dělat, dílenský stav, co se opravdu děje -
/// zaplánování proto stav nezapíše, to dělá až Zahájit.
class PlanVPrubehu extends ConsumerWidget {
  const PlanVPrubehu({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plan = order.planKlempirny;
    // Plán jen s plánovačem „Plánovat" u pobočky zakázky; ten smí i zapsat stav.
    final smiPlan = ref.watch(smiPlanovatProvider(order.branch?.code));
    final smiStav =
        smiPlan || ref.watch(smiZapisovatProvider(order.poradac?.kod));
    final aktualni = order.historieStavu.firstOrNull;
    final kodLaku = kodLakuZakazky(plan, order.barvaVozu);
    void otevri({UkonPlanu? ukon}) => naplanovatKlempirnu(
      context,
      ref,
      zakazkaId: order.id,
      spz: order.licensePlate,
      plan: plan,
      ukon: ukon,
      barva: order.barvaVozu,
    );

    return Column(
      key: const Key('plan-karta'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: Insets.md,
                runSpacing: Insets.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const SectionLabel('PLÁN'),
                  if (plan != null)
                    Text(
                      obdobiPlanu(plan.od, plan.do_),
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (plan != null && kodLaku != null) KodLaku(kod: kodLaku),
                ],
              ),
            ),
            if (plan != null && smiPlan)
              GestureDetector(
                key: const Key('plan-pridat-ukon'),
                onTap: otevri,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    'Přidat úkon',
                    style: AppTextStyles.cardBody.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
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
          if (smiPlan) ...[
            const SizedBox(height: Insets.md),
            FilledButton.icon(
              key: const Key('zaplanovat-klempirnu'),
              onPressed: otevri,
              icon: const Icon(Icons.event_available_outlined, size: 20),
              label: const Text('Zaplánovat na klempírnu/lakovnu'),
            ),
          ],
        ] else
          for (final ukon in plan.ukony) ...[
            _Ukon(
              ukon: ukon,
              stav: stavUkonu(ukon, aktualni),
              onUpravit: smiPlan ? () => otevri(ukon: ukon) : null,
              onZahajit: smiStav
                  ? () => pridatStavZakazce(context, ref, order, ukon: ukon.typ)
                  : null,
            ),
            const SizedBox(height: Insets.sm),
          ],
        if (ref.watch(vidiPlanovacProvider))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('otevrit-planovac'),
              onPressed: () => context.push(cestaPlanovace),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Otevřít plánovač'),
            ),
          ),
      ],
    );
  }
}

/// Jeden úkon v průběhu: proužek v barvě typu, dny, poznámka, a vpravo stav
/// nebo Zahájit.
class _Ukon extends StatelessWidget {
  const _Ukon({
    required this.ukon,
    required this.stav,
    this.onUpravit,
    this.onZahajit,
  });

  final UkonPlanu ukon;
  final StavUkonu stav;

  /// Bez něj (jen čtení) úkon nejde otevřít.
  final VoidCallback? onUpravit;
  final VoidCallback? onZahajit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barva = barvaUkonu(ukon.typ);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.sm,
        Insets.sm,
        Insets.sm,
      ),
      decoration: BoxDecoration(
        color: barva.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: barva, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: Key('plan-ukon-${ukon.id}'),
              onTap: onUpravit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ukon.typ.nazev,
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${obdobiPlanu(ukon.od, ukon.do_)} · ${pocetDni(ukon.dni)}',
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.text,
                    ),
                  ),
                  if (ukon.poznamka.trim().isNotEmpty) ...[
                    const SizedBox(height: Insets.xs),
                    Text(
                      ukon.poznamka,
                      style: AppTextStyles.noteText.copyWith(
                        color: palette.text,
                      ),
                    ),
                  ],
                  if (ukon.zaplanoval != null) ...[
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Zaplánoval ${ukon.zaplanoval}',
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          switch (stav) {
            StavUkonu.hotovo => const StavPlanuZnacka(hotovo: true),
            StavUkonu.probiha => const _Probiha(),
            StavUkonu.ceka =>
              onZahajit == null
                  ? const StavPlanuZnacka(hotovo: false)
                  : OutlinedButton(
                      key: Key('plan-zahajit-${ukon.id}'),
                      onPressed: onZahajit,
                      child: const Text('Zahájit'),
                    ),
          },
        ],
      ),
    );
  }
}

/// Úkon, který odpovídá aktuálnímu dílenskému stavu.
class _Probiha extends StatelessWidget {
  const _Probiha();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Insets.xs),
          Text(
            'PROBÍHÁ',
            style: AppTextStyles.overline.copyWith(
              fontSize: 10,
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
