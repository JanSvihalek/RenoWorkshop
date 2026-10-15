import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/akce_providers.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../domain/prehled_planu.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import 'okno_planu.dart';
import 'plan_karta.dart';
import 'plan_providers.dart';

const _dnyTydne = ['Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'];

/// „Po 12. 10."
String denSNazvem(DateTime d) =>
    '${_dnyTydne[d.weekday - 1]} ${AppDateFormat.dayMonth(d)}';

/// Záložka Plán: klempírna a lakovna po pracovních dnech jako časová osa.
/// Řádek je zakázka, pruh její blok od-do. Klepnutí na pruh plán upraví,
/// klepnutí na zakázku otevře detail. Zaplánovat jde z detailu zakázky.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key, required this.onOpenOrder});

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
            _Ovladani(dny: dny, pobocky: prehled.valueOrNull?.pobocky),
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
  const _Ovladani({required this.dny, required this.pobocky});

  final List<DateTime> dny;
  final List<PobockaPlanu>? pobocky;

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
          Column(
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
    final polozky = [
      for (final p in prehled.polozky)
        if (pobocka == null || p.pobockaKod == pobocka) p,
    ];
    final kody = spolecneKody(polozky, dny.first, dny.last);

    return RefreshIndicator.adaptive(
      onRefresh: () => ref.refresh(planKlempirnyProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(Insets.xl),
        children: [
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

  static const _vyska = 68.0;

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
    // Bez bloku v období jde na den klepnout: nový plán ho má předvyplněný,
    // existující plán jinde se otevře k úpravě.
    void otevri(DateTime den) => naplanovatKlempirnu(
      context,
      ref,
      zakazkaId: polozka.zakazkaId,
      spz: polozka.spz,
      plan: plan,
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
                                onTap: () => otevri(d),
                                child: plan == null
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
  });

  final PolozkaPlanu polozka;
  final PlanKlempirny plan;
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
        onTap: () => naplanovatKlempirnu(
          context,
          ref,
          zakazkaId: polozka.zakazkaId,
          spz: polozka.spz,
          plan: plan,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          child: Row(
            children: [
              if (plan.hotovo) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: Insets.xs),
              ],
              if (plan.kodLaku != null) ...[
                KodLaku(kod: plan.kodLaku!, naPruhu: true),
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
