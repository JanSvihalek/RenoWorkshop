import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/akce_providers.dart';
import '../../orders/domain/entities/order_filter.dart';
import '../../orders/domain/entities/service_order.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../../orders/presentation/widgets/filtr_lista.dart' show FiltrVyber;
import '../../orders/presentation/widgets/order_status_visuals.dart';
import '../../orders/presentation/widgets/pridat_stav_sheet.dart';
import '../domain/prehled_planu.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import 'okno_planu.dart';
import 'plan_karta.dart';
import 'plan_providers.dart';

const _dnyTydne = ['Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'];

/// „Po 12. 10."
String denSNazvem(DateTime d) =>
    '${_dnyTydne[d.weekday - 1]} ${AppDateFormat.dayMonth(d)}';

/// Cesta plánovače v appce - otevírá ho přepínač aplikací a karta
/// Klempírna / lakovna v detailu zakázky.
const cestaPlanovace = '/planovac';

/// Plánovač klempírny a lakovny - jako portál plánu na webu: po pracovních
/// dnech jako časová osa. Řádek je zakázka s průběhem na dílně (dílenský
/// stav), pruh její blok od-do. Klepnutí na pruh plán upraví, na den
/// zaplánuje, na zakázku otevře detail, na stav zapíše nový.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({
    super.key,
    required this.onBack,
    required this.onOpenOrder,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prehled = ref.watch(planKlempirnyProvider);
    final zacatek = ref.watch(planZacatekProvider);
    final tydnu = ref.watch(planTydnuProvider);
    final dny = pracovniDny(zacatek, tydnu);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Ovladani(
              dny: dny,
              pobocky: prehled.valueOrNull?.pobocky,
              onBack: onBack,
            ),
            Expanded(
              child: prehled.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (chyba, _) => _Chyba(
                  text: chyba is ServiceOrderException
                      ? chyba.message
                      : 'Plán se nepodařilo načíst.',
                  onZnovu: () => ref.invalidate(planKlempirnyProvider),
                ),
                data: (p) =>
                    _Obsah(prehled: p, dny: dny, onOpenOrder: onOpenOrder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nadpis, pobočka, týden / 14 dní a posun po týdnech.
class _Ovladani extends ConsumerWidget {
  const _Ovladani({
    required this.dny,
    required this.pobocky,
    required this.onBack,
  });

  final List<DateTime> dny;
  final List<PobockaPlanu>? pobocky;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tydnu = ref.watch(planTydnuProvider);
    final pobocka = vybranaPobocka(ref, pobocky);
    void posun(int tydny) {
      final z = ref.read(planZacatekProvider);
      ref.read(planZacatekProvider.notifier).state = DateTime(
        z.year,
        z.month,
        z.day + tydny * 7,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.lg,
        Insets.xl,
        Insets.base,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Wrap(
        spacing: Insets.lg,
        runSpacing: Insets.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('plan-zpet-do-zakazek'),
                tooltip: 'Zpět',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: Insets.xs),
              Flexible(child: _Nadpis(palette: palette)),
            ],
          ),
          if (pobocky case final nabidka? when nabidka.length > 1)
            Wrap(
              spacing: Insets.sm,
              children: [
                for (final p in nabidka)
                  ChoiceChip(
                    key: Key('plan-pobocka-${p.kod}'),
                    label: Text(p.nazev),
                    selected: p.kod == pobocka,
                    onSelected: (_) =>
                        ref.read(planPobockaProvider.notifier).state = p.kod,
                  ),
              ],
            ),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                key: const Key('plan-rozsah'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('Týden')),
                  ButtonSegment(value: 2, label: Text('14 dní')),
                ],
                selected: {tydnu},
                onSelectionChanged: (v) =>
                    ref.read(planTydnuProvider.notifier).state = v.first,
              ),
              OutlinedButton(
                key: const Key('plan-dnes'),
                onPressed: () => ref.read(planZacatekProvider.notifier).state =
                    pondeli(ref.read(dnesProvider)),
                child: const Text('Dnes'),
              ),
              // Šipky s obdobím drží pohromadě - na telefonu se zalamuje
              // celý blok, ne šipka zvlášť.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    key: const Key('plan-zpet'),
                    tooltip: 'Předchozí',
                    onPressed: () => posun(-tydnu),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  // Na úzkém telefonu se raději zkrátí, než aby přeteklo.
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                      child: Text(
                        obdobiPlanu(dny.first, dny.last),
                        key: const Key('plan-obdobi-text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardBody.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    key: const Key('plan-dal'),
                    tooltip: 'Další',
                    onPressed: () => posun(tydnu),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Nadpis extends StatelessWidget {
  const _Nadpis({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plán klempírny a lakovny',
          style: AppTextStyles.sectionTitle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        Text(
          'zakázky klempířských středisek · klepnutím na den zaplánujete',
          style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

/// Kód vybrané pobočky - bez volby první z nabídky.
String? vybranaPobocka(WidgetRef ref, List<PobockaPlanu>? pobocky) {
  final vybrana = ref.watch(planPobockaProvider);
  if (pobocky == null || pobocky.isEmpty) return vybrana;
  return pobocky.any((p) => p.kod == vybrana) ? vybrana : pobocky.first.kod;
}

class _Obsah extends ConsumerWidget {
  const _Obsah({
    required this.prehled,
    required this.dny,
    required this.onOpenOrder,
  });

  final PrehledPlanu prehled;
  final List<DateTime> dny;
  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final pobocka = vybranaPobocka(ref, prehled.pobocky);
    final vsechny = [
      for (final p in prehled.polozky)
        if (pobocka == null || p.pobockaKod == pobocka) p,
    ];
    final polozky = filtrujPlan(
      vsechny,
      filtr: ref.watch(planFiltrProvider),
      kodLaku: ref.watch(planKodLakuProvider),
      stavPlanu: ref.watch(planStavPlanuProvider),
    );
    final kody = spolecneKody(polozky, dny.first, dny.last);

    return RefreshIndicator.adaptive(
      onRefresh: () => ref.refresh(planKlempirnyProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(Insets.xl),
        children: [
          _FiltryPlanu(polozky: vsechny),
          const SizedBox(height: Insets.md),
          Text(
            polozky.length == vsechny.length
                ? '${polozky.length} zakázek'
                : '${polozky.length} z ${vsechny.length} zakázek',
            key: const Key('plan-pocet'),
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.md),
          if (kody.isNotEmpty) ...[
            _SpolecneKody(kody: kody),
            const SizedBox(height: Insets.lg),
          ],
          Container(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: palette.hairline),
              boxShadow: palette.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: _Osa(polozky: polozky, dny: dny, onOpenOrder: onOpenOrder),
          ),
        ],
      ),
    );
  }
}

/// Kódy laku, které se v období opakují - jdou lakovat v jedné várce.
class _SpolecneKody extends StatelessWidget {
  const _SpolecneKody({required this.kody});

  final List<SpolecnyKod> kody;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('plan-spolecne-kody'),
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Wrap(
        spacing: Insets.md,
        runSpacing: Insets.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.palette_outlined, size: 20, color: palette.text),
              const SizedBox(width: Insets.sm),
              Text(
                'Společné kódy laku',
                style: AppTextStyles.cardBody.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ],
          ),
          for (final k in kody)
            Container(
              key: Key('plan-kod-${k.kod}'),
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: k.kod,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text:
                          '  ${k.polozky.length}× · '
                          '${k.polozky.map((p) => p.spz.isEmpty ? p.zakazkaId : p.spz).join(', ')}',
                    ),
                  ],
                ),
                style: AppTextStyles.metaSmall.copyWith(color: palette.text),
              ),
            ),
        ],
      ),
    );
  }
}

/// Časová osa: záhlaví dnů, pod ním řádek na zakázku. Když se dny do
/// šířky nevejdou (telefon), osa se posouvá do stran.
class _Osa extends StatelessWidget {
  const _Osa({
    required this.polozky,
    required this.dny,
    required this.onOpenOrder,
  });

  final List<PolozkaPlanu> polozky;
  final List<DateTime> dny;
  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final levy = constraints.maxWidth >= 900 ? 250.0 : 150.0;
        final den = math.max(
          dny.length > 5 ? 64.0 : 76.0,
          (constraints.maxWidth - levy) / dny.length,
        );
        final sirka = levy + den * dny.length;
        final radky = rozdelPolozky(polozky, dny.first, dny.last);

        final mrizka = SizedBox(
          width: sirka,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ZahlaviDnu(dny: dny, levy: levy, den: den),
              if (polozky.isEmpty) const _Prazdno(),
              for (final (nadpis, sekce) in [
                (null, radky.vObdobi),
                ('NAPLÁNOVANÉ JINDY', radky.jindy),
                ('BEZ PLÁNU', radky.bezPlanu),
              ])
                if (sekce.isNotEmpty) ...[
                  if (nadpis != null)
                    _NadpisSekce(text: '$nadpis · ${sekce.length}'),
                  for (final p in sekce)
                    _Radek(
                      polozka: p,
                      dny: dny,
                      levy: levy,
                      den: den,
                      onOpenOrder: onOpenOrder,
                    ),
                ],
            ],
          ),
        );
        return sirka > constraints.maxWidth + 0.5
            ? SingleChildScrollView(
                key: const Key('plan-osa-posun'),
                scrollDirection: Axis.horizontal,
                child: mrizka,
              )
            : mrizka;
      },
    );
  }
}

class _ZahlaviDnu extends ConsumerWidget {
  const _ZahlaviDnu({required this.dny, required this.levy, required this.den});

  final List<DateTime> dny;
  final double levy;
  final double den;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final dnes = ref.watch(dnesProvider);
    final styl = AppTextStyles.metaSmall.copyWith(
      fontWeight: FontWeight.w700,
      color: palette.text,
    );

    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: levy,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.base),
              child: Text('Zakázka', style: styl),
            ),
          ),
          for (final d in dny)
            Container(
              width: den,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _jeDnes(d, dnes)
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : null,
                border: Border(left: BorderSide(color: palette.hairline)),
              ),
              child: Text(
                denSNazvem(d),
                style: _jeDnes(d, dnes)
                    ? styl.copyWith(color: AppColors.accent)
                    : styl,
              ),
            ),
        ],
      ),
    );
  }
}

bool _jeDnes(DateTime d, DateTime dnes) =>
    d.year == dnes.year && d.month == dnes.month && d.day == dnes.day;

/// Řádek zakázky: vlevo vůz a zákazník, vpravo pruh přes dny plánu.
class _Radek extends ConsumerWidget {
  const _Radek({
    required this.polozka,
    required this.dny,
    required this.levy,
    required this.den,
    required this.onOpenOrder,
  });

  final PolozkaPlanu polozka;
  final List<DateTime> dny;
  final double levy;
  final double den;
  final ValueChanged<String> onOpenOrder;

  static const _vyska = 102.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final dnes = ref.watch(dnesProvider);
    final plan = polozka.plan;
    // Které zobrazené dny blok zabírá - víkendy v ose nejsou.
    final prvni = plan == null
        ? -1
        : dny.indexWhere((d) => !d.isBefore(plan.od));
    final posledni = plan == null
        ? -1
        : dny.lastIndexWhere((d) => !d.isAfter(plan.do_));
    final viditelny = prvni != -1 && posledni >= prvni;
    // Jen čtení (právo R k pořadači) - plán i stav jen vidí.
    final smi = ref.watch(smiZapisovatProvider(polozka.zakazka?.poradac?.kod));
    // Bez bloku v období jde na den klepnout: nový plán ho má předvyplněný,
    // existující plán jinde se otevře k úpravě.
    void otevri(DateTime den) => naplanovatKlempirnu(
      context,
      ref,
      zakazkaId: polozka.zakazkaId,
      spz: polozka.spz,
      plan: plan,
      barva: polozka.barva,
      den: den,
    );

    return Container(
      key: Key('plan-radek-${polozka.zakazkaId}'),
      height: _vyska,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: levy,
            child: InkWell(
              key: Key('plan-zakazka-${polozka.zakazkaId}'),
              onTap: () => onOpenOrder(polozka.zakazkaId),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.base),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (polozka.spz.isNotEmpty) polozka.spz,
                        if (polozka.model.isNotEmpty) polozka.model,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardBody.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      '${polozka.zakazkaId} · ${polozka.zakaznik}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                    if (polozka.zakazka case final zakazka?) ...[
                      // VIN a kdo zodpovídá - jeden řádek, co se nevejde,
                      // je v detailu zakázky.
                      if (_vozARuce(zakazka) case final text?)
                        Text(
                          text,
                          key: Key('plan-vuz-${polozka.zakazkaId}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.metaSmall.copyWith(
                            fontSize: 11,
                            color: palette.muted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      _StavDilny(zakazka: zakazka, smi: smi),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: den * dny.length,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (final d in dny)
                      Container(
                        width: den,
                        decoration: BoxDecoration(
                          color: _jeDnes(d, dnes)
                              ? AppColors.accent.withValues(alpha: 0.05)
                              : null,
                          border: Border(
                            left: BorderSide(color: palette.hairline),
                          ),
                        ),
                        child: viditelny
                            ? null
                            : InkWell(
                                key: Key(
                                  'plan-den-${polozka.zakazkaId}-${d.day}',
                                ),
                                onTap: smi ? () => otevri(d) : null,
                                child: plan == null && smi
                                    ? Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: palette.muted.withValues(
                                          alpha: 0.45,
                                        ),
                                      )
                                    : null,
                              ),
                      ),
                  ],
                ),
                // Plán mimo zobrazené dny - aspoň kdy je.
                if (plan != null && !viditelny)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          '${plan.hotovo ? 'Hotovo' : 'Naplánováno'} '
                          '${obdobiPlanu(plan.od, plan.do_)}',
                          key: Key('plan-jindy-${polozka.zakazkaId}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.metaSmall.copyWith(
                            color: palette.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (viditelny)
                  Positioned(
                    left: prvni * den + 4,
                    width: (posledni - prvni + 1) * den - 8,
                    top: 10,
                    bottom: 10,
                    child: _Pruh(
                      polozka: polozka,
                      smi: smi,
                      plan: plan!,
                      useknutyZleva: plan.od.isBefore(dny[prvni]),
                      useknutyZprava: plan.do_.isAfter(dny[posledni]),
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

/// Blok zakázky na ose: modrý naplánovaný, zelený hotový.
class _Pruh extends ConsumerWidget {
  const _Pruh({
    required this.polozka,
    required this.plan,
    required this.useknutyZleva,
    required this.useknutyZprava,
    this.smi = true,
  });

  final PolozkaPlanu polozka;
  final PlanKlempirny plan;

  /// Jen čtení - klepnutím se plán neotevře k úpravě.
  final bool smi;
  final bool useknutyZleva;
  final bool useknutyZprava;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barva = plan.hotovo ? AppColors.readyGreen : AppColors.accent;
    const r = Radius.circular(8);

    return Material(
      color: barva,
      borderRadius: BorderRadius.horizontal(
        left: useknutyZleva ? Radius.zero : r,
        right: useknutyZprava ? Radius.zero : r,
      ),
      child: InkWell(
        key: Key('plan-pruh-${polozka.zakazkaId}'),
        onTap: smi
            ? () => naplanovatKlempirnu(
                context,
                ref,
                zakazkaId: polozka.zakazkaId,
                spz: polozka.spz,
                plan: plan,
                barva: polozka.barva,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          child: Row(
            children: [
              if (plan.hotovo) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: Insets.xs),
              ],
              if (polozka.kodLaku case final kod?) ...[
                KodLaku(kod: kod, naPruhu: true),
                const SizedBox(width: Insets.sm),
              ],
              Expanded(
                child: Text(
                  plan.poznamka.trim().isNotEmpty
                      ? plan.poznamka.trim()
                      : obdobiPlanu(plan.od, plan.do_),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metaSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oddělovač skupiny řádků - naplánované jindy, bez plánu.
class _NadpisSekce extends StatelessWidget {
  const _NadpisSekce({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.base,
        Insets.md,
        Insets.base,
        Insets.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Text(
        text,
        style: AppTextStyles.overline.copyWith(color: palette.muted),
      ),
    );
  }
}

class _Prazdno extends StatelessWidget {
  const _Prazdno();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      key: const Key('plan-prazdny'),
      padding: const EdgeInsets.all(Insets.xxl),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 36, color: palette.muted),
          const SizedBox(height: Insets.sm),
          Text(
            'Klempírna pobočky teď nemá žádné zakázky.',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardBody.copyWith(color: palette.text),
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            'V plánu jsou rozdělané zakázky klempířských středisek '
            'a vše, co je v tomto období naplánované.',
            textAlign: TextAlign.center,
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Chyba extends StatelessWidget {
  const _Chyba({required this.text, required this.onZnovu});

  final String text;
  final VoidCallback onZnovu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
            TextButton(onPressed: onZnovu, child: const Text('Zkusit znovu')),
          ],
        ),
      ),
    );
  }
}

/// Řádky plánu po filtru: jako seznam zakázek ([OrderFilter]) a navíc kód
/// laku a stav plánu. Řádek bez celé zakázky (starší API) filtr zakázek
/// nezahodí.
List<PolozkaPlanu> filtrujPlan(
  List<PolozkaPlanu> polozky, {
  required OrderFilter filtr,
  String? kodLaku,
  StavPlanuFiltr? stavPlanu,
}) => [
  for (final p in polozky)
    if ((p.zakazka == null || filtr.matches(p.zakazka!)) &&
        (kodLaku == null || p.kodLaku == kodLaku) &&
        (stavPlanu == null || stavPlanu.sedi(p.plan)))
      p,
];

/// Průběh na dílně pod zakázkou: poslední dílenský stav, poznámka (co se
/// právě dělá) a kdy. Klepnutím se zapíše nový - stejné okno jako v detailu.
class _StavDilny extends ConsumerWidget {
  const _StavDilny({required this.zakazka, this.smi = true});

  final ServiceOrder zakazka;

  /// Jen čtení - stav ukáže, nový nezapíše.
  final bool smi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final stav = zakazka.stav;
    final dnes = ref.watch(dnesProvider);
    final kdy = stav?.zadano;
    final cas = kdy == null
        ? null
        : _jeDnes(kdy, dnes)
        ? AppDateFormat.time(kdy)
        : AppDateFormat.dayMonth(kdy);

    return GestureDetector(
      key: Key('plan-stav-${zakazka.id}'),
      onTap: smi ? () => pridatStavZakazce(context, ref, zakazka) : null,
      behavior: HitTestBehavior.opaque,
      // V úzkém sloupci (telefon) se zkracuje štítek i poznámka, čas zůstává.
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: stav?.color ?? AppColors.pickedUpGrey,
                borderRadius: BorderRadius.circular(Radii.badge),
              ),
              child: Text(
                stav?.nazev ?? 'Bez stavu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.badge.copyWith(
                  fontSize: 10.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (stav?.poznamka case final poznamka?) ...[
            const SizedBox(width: Insets.xs),
            Flexible(
              child: Text(
                poznamka,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.metaSmall.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (cas != null) ...[
            const SizedBox(width: Insets.xs),
            Text(
              cas,
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Filtry plánu - hledání a stejné výběry jako lišta seznamu zakázek,
/// navíc kód laku a stav plánu. Nabídka jen z hodnot, které v plánu jsou.
class _FiltryPlanu extends ConsumerStatefulWidget {
  const _FiltryPlanu({required this.polozky});

  final List<PolozkaPlanu> polozky;

  @override
  ConsumerState<_FiltryPlanu> createState() => _FiltryPlanuState();
}

class _FiltryPlanuState extends ConsumerState<_FiltryPlanu> {
  late final _hledani = TextEditingController(
    text: ref.read(planFiltrProvider).query,
  );

  @override
  void dispose() {
    _hledani.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filtr = ref.watch(planFiltrProvider);
    final kodLaku = ref.watch(planKodLakuProvider);
    final stavPlanu = ref.watch(planStavPlanuProvider);
    void zmen(OrderFilter Function(OrderFilter f) zmena) =>
        ref.read(planFiltrProvider.notifier).update(zmena);

    final zakazky = [for (final p in widget.polozky) ?p.zakazka];
    Map<K, String> serad<K>(Map<K, String> m) => Map.fromEntries(
      m.entries.toList()..sort((a, b) => a.value.compareTo(b.value)),
    );
    final utvary = serad({
      for (final z in zakazky)
        if (z.department case final u?) u.code: u.code,
    });
    final poradace = serad({
      for (final z in zakazky)
        if (z.poradac case final p?) p.kod: p.nazev,
    });
    final helios = serad({
      for (final s in zakazky.map((z) => z.heliosStatus).nonNulls) s: s,
    });
    final stavy = serad({
      for (final z in zakazky)
        if (z.stav case final s? when s.kod != null) s.kod!: s.nazev,
    });
    final lide = serad({
      for (final m in zakazky.map((z) => z.mechanicName).nonNulls) m: m,
    });
    final zpracovatele = <int, String>{
      OrderFilter.nikdo: 'Nikdo',
      ...serad({
        for (final z in zakazky)
          if (z.zpracovatel case final k?) k.id: k.jmeno,
      }),
    };
    final kody = serad({
      for (final k in widget.polozky.map((p) => p.kodLaku).nonNulls) k: k,
    });
    final aktivni = filtr.isActive || kodLaku != null || stavPlanu != null;

    Widget mezera() => const SizedBox(width: Insets.sm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('plan-hledani'),
          controller: _hledani,
          onChanged: (text) => zmen((f) => f.copyWith(query: text)),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'SPZ, VIN, zakázka, zákazník…',
            filled: true,
            fillColor: palette.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: palette.hairline2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: palette.hairline2),
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FiltrVyber<String>(
                popisek: 'Útvar',
                hodnota: filtr.departmentCode,
                moznosti: utvary,
                onZmena: (v) => zmen(
                  (f) =>
                      f.copyWith(departmentCode: v, clearDepartment: v == null),
                ),
              ),
              mezera(),
              FiltrVyber<String>(
                popisek: 'Pořadač',
                hodnota: filtr.poradacKod,
                moznosti: poradace,
                onZmena: (v) => zmen(
                  (f) => f.copyWith(poradacKod: v, clearPoradac: v == null),
                ),
              ),
              mezera(),
              FiltrVyber<String>(
                popisek: 'Stav Helios',
                hodnota: filtr.heliosStav,
                moznosti: helios,
                onZmena: (v) => zmen(
                  (f) => f.copyWith(heliosStav: v, clearHeliosStav: v == null),
                ),
              ),
              mezera(),
              FiltrVyber<String>(
                key: const Key('plan-filtr-stav'),
                popisek: 'Stav dílna',
                hodnota: filtr.statusCode,
                moznosti: stavy,
                onZmena: (v) => zmen(
                  (f) => f.copyWith(statusCode: v, clearStatus: v == null),
                ),
              ),
              mezera(),
              FiltrVyber<String>(
                popisek: 'Zodpovídá',
                hodnota: filtr.mechanicName,
                moznosti: lide,
                onZmena: (v) => zmen(
                  (f) => f.copyWith(mechanicName: v, clearMechanic: v == null),
                ),
              ),
              mezera(),
              FiltrVyber<int>(
                popisek: 'Zpracovává',
                hodnota: filtr.zpracovatelId,
                moznosti: zpracovatele,
                onZmena: (v) => zmen(
                  (f) =>
                      f.copyWith(zpracovatelId: v, clearZpracovatel: v == null),
                ),
              ),
              mezera(),
              FiltrVyber<String>(
                key: const Key('plan-filtr-kod'),
                popisek: 'Kód laku',
                hodnota: kodLaku,
                moznosti: kody,
                onZmena: (v) =>
                    ref.read(planKodLakuProvider.notifier).state = v,
              ),
              mezera(),
              FiltrVyber<StavPlanuFiltr>(
                key: const Key('plan-filtr-stav-planu'),
                popisek: 'Stav plánu',
                hodnota: stavPlanu,
                moznosti: {for (final s in StavPlanuFiltr.values) s: s.label},
                onZmena: (v) =>
                    ref.read(planStavPlanuProvider.notifier).state = v,
              ),
              if (aktivni) ...[
                mezera(),
                TextButton(
                  key: const Key('plan-zrusit-filtry'),
                  onPressed: () {
                    _hledani.clear();
                    ref.read(planFiltrProvider.notifier).state =
                        const OrderFilter();
                    ref.read(planKodLakuProvider.notifier).state = null;
                    ref.read(planStavPlanuProvider.notifier).state = null;
                  },
                  child: const Text('Zrušit filtry'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// „VIN G980042 · Zodpovídá: Jan Dvořák", nebo `null`, když není ani
/// jedno. VIN krátký (posledních 7 znaků, jak ho BMW používá) - celý by
/// v úzkém sloupci jméno vytlačil; celý je v detailu zakázky.
String? _vozARuce(ServiceOrder zakazka) {
  final vin = zakazka.vin;
  final casti = [
    if (vin.isNotEmpty)
      'VIN ${vin.length > 7 ? vin.substring(vin.length - 7) : vin}',
    if (zakazka.mechanicName case final kdo? when kdo.isNotEmpty)
      'Zodpovídá: $kdo',
  ];
  return casti.isEmpty ? null : casti.join(' · ');
}
