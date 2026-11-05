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
import '../../orders/presentation/controllers/order_actions_controller.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../../orders/presentation/widgets/filtr_lista.dart' show FiltrVyber;
import '../../orders/presentation/widgets/order_status_visuals.dart';
import '../../orders/presentation/widgets/pridat_stav_sheet.dart';
import '../domain/prehled_planu.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../uzivatele/presentation/uzivatele_screen.dart';
import 'kapacita_screen.dart';
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
/// stav), pruhy její úkony od-do, překrývající se pod sebou. Klepnutí na
/// pruh úkon upraví, na den přidá nový, na zakázku otevře detail, na stav
/// zapíše nový.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({
    super.key,
    required this.onBack,
    required this.onOpenOrder,
    required this.onOpenSettings,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onOpenOrder;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prehled = ref.watch(planKlempirnyProvider);
    final zacatek = ref.watch(planZacatekProvider);
    final tydnu = ref.watch(planTydnuProvider);
    final dny = dnyOsy(zacatek, tydnu);

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
              onOpenSettings: onOpenSettings,
            ),
            Expanded(
              child: !ref.watch(vidiPlanovacProvider)
                  ? const _Chyba(
                      key: Key('plan-bez-pristupu'),
                      text:
                          'Plánovač vám není přístupný.\n'
                          'Přístup k plánovači klempírny vám nastaví admin.',
                    )
                  : prehled.when(
                      skipLoadingOnReload: true,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (chyba, _) => _Chyba(
                        text: chyba is ServiceOrderException
                            ? chyba.message
                            : 'Plán se nepodařilo načíst.',
                        onZnovu: () => ref.invalidate(planKlempirnyProvider),
                      ),
                      data: (p) => _Obsah(
                        prehled: p,
                        dny: dny,
                        onOpenOrder: onOpenOrder,
                      ),
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
    required this.onOpenSettings,
  });

  final List<DateTime> dny;
  final List<PobockaPlanu>? pobocky;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;

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
              IconButton(
                key: const Key('plan-nastaveni'),
                tooltip: 'Nastavení',
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              // Kapacitu dílen upravuje jen mistr a vedoucí, nastavuje admin.
              if (pobocka != null && ref.watch(smiKapacituProvider(pobocka)))
                IconButton(
                  key: const Key('plan-kapacita'),
                  tooltip: 'Kapacita dílen',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => KapacitaScreen(
                        pobocka: pobocka,
                        nazev:
                            pobocky
                                ?.where((p) => p.kod == pobocka)
                                .firstOrNull
                                ?.nazev ??
                            pobocka,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.groups_outlined),
                ),
              // Admin jako v portálu plánu na webu - jen pro admina.
              if (ref.watch(mojePravaProvider).valueOrNull?.jeAdmin ?? false)
                IconButton(
                  key: const Key('plan-admin'),
                  tooltip: 'Admin',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UzivateleScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.admin_panel_settings),
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
          'Klepnutím na hlavičku dne zobrazíte vytížení · klepnutím do mřížky '
          'přidáte úkon',
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
    // Z celé pobočky - vytížení dílny na filtru nezávisí.
    final zatez = vytizeniDilen(vsechny);
    final kapacity =
        prehled.kapacity[pobocka] ??
        const <DateTime, Map<Dilna, KapacitaDne>>{};

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
          const SizedBox(height: Insets.sm),
          const _Legenda(),
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
            child: _Osa(
              polozky: polozky,
              dny: dny,
              zatez: zatez,
              kapacity: kapacity,
              onOpenOrder: onOpenOrder,
            ),
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
    required this.zatez,
    required this.kapacity,
    required this.onOpenOrder,
  });

  final List<PolozkaPlanu> polozky;
  final List<DateTime> dny;
  final Map<DateTime, Map<Dilna, double>> zatez;
  final Map<DateTime, Map<Dilna, KapacitaDne>> kapacity;
  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final levy = constraints.maxWidth >= 900 ? 250.0 : 150.0;
        final sirky = sirkySloupcu(dny, constraints.maxWidth - levy);
        final sirka = sirky.fold(levy, (soucet, s) => soucet + s);
        final radky = rozdelPolozky(polozky, dny.first, dny.last);

        final mrizka = SizedBox(
          width: sirka,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ZahlaviDnu(
                dny: dny,
                levy: levy,
                sirky: sirky,
                zatez: zatez,
                kapacity: kapacity,
              ),
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
                      sirky: sirky,
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
  const _ZahlaviDnu({
    required this.dny,
    required this.levy,
    required this.sirky,
    required this.zatez,
    required this.kapacity,
  });

  final List<DateTime> dny;
  final double levy;
  final List<double> sirky;
  final Map<DateTime, Map<Dilna, double>> zatez;
  final Map<DateTime, Map<Dilna, KapacitaDne>> kapacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final dnes = ref.watch(dnesProvider);
    final styl = AppTextStyles.metaSmall.copyWith(
      fontWeight: FontWeight.w700,
      color: palette.text,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: levy,
              child: Padding(
                padding: const EdgeInsets.all(Insets.base),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zakázka', style: styl),
                    Text(
                      'Vytížení K · P · L · celkem',
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final (i, d) in dny.indexed)
              _HlavickaDne(
                key: Key('plan-hlavicka-${d.day}'),
                den: d,
                dny: dny,
                sirka: sirky[i],
                dnes: _jeDnes(d, dnes),
                novyTyden: i > 0 && i % 7 == 0,
                vytizeni: vytizeniDne(zatez[d], kapacity[d]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barvy pásma vytížení - jediný zdroj pro ukazatel, detail i legendu.
({Color segment, Color text, Color pozadi, Color naPozadi}) _barvyVytizeni(
  BuildContext context,
  UrovenVytizeni? uroven,
) {
  final palette = context.palette;
  final tmava = context.isDarkMode;
  return switch (uroven) {
    UrovenVytizeni.pres => (
      segment: tmava ? const Color(0xFFFF7A7A) : const Color(0xFFC62828),
      text: tmava ? const Color(0xFFFF7A7A) : const Color(0xFFB71C1C),
      pozadi: tmava ? const Color(0x29FF7A7A) : const Color(0xFFFDE3E3),
      naPozadi: tmava ? const Color(0xFFFF7A7A) : const Color(0xFFB71C1C),
    ),
    UrovenVytizeni.plno => (
      segment: tmava ? const Color(0xFFE8A93A) : const Color(0xFFE0A100),
      text: tmava ? const Color(0xFFE8A93A) : const Color(0xFF8A5A00),
      pozadi: tmava ? const Color(0x29E8A93A) : const Color(0xFFFFF1D6),
      naPozadi: tmava ? const Color(0xFFE8A93A) : const Color(0xFF8A5A00),
    ),
    UrovenVytizeni.ok => (
      segment: AppColors.accent,
      text: tmava ? const Color(0xFF8CC0FF) : const Color(0xFF1F4F8F),
      pozadi: tmava ? const Color(0x294599FE) : const Color(0xFFEAF2FC),
      naPozadi: tmava ? const Color(0xFF8CC0FF) : const Color(0xFF1F4F8F),
    ),
    UrovenVytizeni.nizke => (
      segment: tmava ? const Color(0xFF5FD38D) : const Color(0xFF2E9E5B),
      text: tmava ? const Color(0xFF5FD38D) : const Color(0xFF1B6E3C),
      pozadi: tmava ? const Color(0x295FD38D) : const Color(0xFFE3F5EA),
      naPozadi: tmava ? const Color(0xFF5FD38D) : const Color(0xFF1B6E3C),
    ),
    _ => (
      segment: tmava ? const Color(0x3DFFFFFF) : const Color(0xFFC9D6DE),
      text: palette.muted2,
      pozadi: tmava ? const Color(0x14FFFFFF) : const Color(0xFFF1F4F6),
      naPozadi: palette.muted,
    ),
  };
}

/// Hlavička dne: datum a tři segmenty K/P/L s celkovým procentem. Klepnutím se
/// otevře rozpad po dílnách. Víkend ukazatel nemá a klepnout na něj nejde.
class _HlavickaDne extends StatefulWidget {
  const _HlavickaDne({
    super.key,
    required this.den,
    required this.dny,
    required this.sirka,
    required this.dnes,
    required this.novyTyden,
    required this.vytizeni,
  });

  final DateTime den;
  final List<DateTime> dny;
  final double sirka;
  final bool dnes;
  final bool novyTyden;
  final ({List<(Dilna, RadekVytizeni)> dilny, RadekVytizeni celkem}) vytizeni;

  @override
  State<_HlavickaDne> createState() => _HlavickaDneState();
}

class _HlavickaDneState extends State<_HlavickaDne> {
  bool _otevreno = false;

  /// Klepnutí mimo detail ho jen zavře - úkon se tím omylem nezaloží.
  Future<void> _otevriDetail() async {
    final box = context.findRenderObject()! as RenderBox;
    final kotva = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _otevreno = true);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zavřít',
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => _DetailVytizeni(
        den: widget.den,
        kotva: kotva,
        vytizeni: widget.vytizeni,
      ),
    );
    if (mounted) setState(() => _otevreno = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final d = widget.den;
    final vikend = jeVikend(d);
    final kompaktni = widget.dny.length > 7;
    final tmava = context.isDarkMode;
    final barvaDatumu = widget.dnes
        ? (tmava ? AppColors.accent : const Color(0xFF1F6FE0))
        : null;

    return Container(
      width: widget.sirka,
      decoration: BoxDecoration(
        color: _otevreno
            ? (tmava ? const Color(0x474599FE) : const Color(0xFFDCEBFF))
            : widget.dnes
            ? (tmava ? const Color(0x244599FE) : const Color(0xFFEEF5FF))
            : vikend
            ? palette.background
            : null,
        border: Border(
          left: BorderSide(
            color: widget.novyTyden ? palette.hairline2 : palette.hairline,
            width: widget.novyTyden ? 2 : 1,
          ),
          bottom: widget.dnes
              ? const BorderSide(color: AppColors.accent, width: 2)
              : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: vikend ? null : _otevriDetail,
        child: Padding(
          padding: kompaktni
              ? const EdgeInsets.all(Insets.sm)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _dnyTydne[d.weekday - 1],
                style: AppTextStyles.metaSmall.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: barvaDatumu ?? palette.muted,
                ),
              ),
              Text(
                jeUzkyDen(d, widget.dny)
                    ? '${d.day}.'
                    : AppDateFormat.dayMonth(d),
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: barvaDatumu ?? (vikend ? palette.muted : palette.text),
                ),
              ),
              if (!vikend) ...[
                const SizedBox(height: 6),
                _MiniUkazatel(
                  den: d,
                  vytizeni: widget.vytizeni,
                  kompaktni: kompaktni,
                  maxSirkaCelkem:
                      (widget.sirka - (kompaktni ? 2 * Insets.sm : 24)) * 0.65,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tři segmenty K/P/L a celkem. Barvu nese celý segment, délka je stálá.
class _MiniUkazatel extends StatelessWidget {
  const _MiniUkazatel({
    required this.den,
    required this.vytizeni,
    required this.kompaktni,
    required this.maxSirkaCelkem,
  });

  final DateTime den;
  final ({List<(Dilna, RadekVytizeni)> dilny, RadekVytizeni celkem}) vytizeni;
  final bool kompaktni;

  /// Aspoň zbytek šířky zůstane segmentům. Hlavička má vlastní výšku podle
  /// obsahu (IntrinsicHeight), takže šířku počítá ona, ne LayoutBuilder.
  final double maxSirkaCelkem;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final celkem = vytizeni.celkem;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (final (i, (dilna, radek)) in vytizeni.dilny.indexed) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        key: Key('plan-segment-${den.day}-${dilna.kod}'),
                        height: kompaktni ? 6 : 8,
                        decoration: BoxDecoration(
                          color: _barvyVytizeni(context, radek.uroven).segment,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (!kompaktni)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dilna.nazev[0],
                            style: AppTextStyles.monoLabel.copyWith(
                              fontSize: 10.5,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w600,
                              color: palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Dlouhé hodiny se raději zmenší, než aby segmenty zmizely.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSirkaCelkem),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  celkem.procentText,
                  key: Key('plan-mini-${den.day}'),
                  style: AppTextStyles.monoLabel.copyWith(
                    fontSize: 12,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                    color: _barvyVytizeni(context, celkem.uroven).text,
                  ),
                ),
                if (!kompaktni)
                  Text(
                    celkem.hodinyZKapacity,
                    key: Key('plan-mini-hodiny-${den.day}'),
                    style: AppTextStyles.monoLabel.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 0,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Rozpad vytížení dne po dílnách pod hlavičkou dne.
class _DetailVytizeni extends StatelessWidget {
  const _DetailVytizeni({
    required this.den,
    required this.kotva,
    required this.vytizeni,
  });

  static const _sirka = 230.0;

  final DateTime den;
  final Rect kotva;
  final ({List<(Dilna, RadekVytizeni)> dilny, RadekVytizeni celkem}) vytizeni;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final obrazovka = MediaQuery.sizeOf(context);
    // U posledních sloupců doprava, ať nepřeteče.
    final doprava = kotva.left + 4 + _sirka > obrazovka.width - Insets.sm
        ? kotva.right - _sirka - 4
        : kotva.left + 4;
    // Hlavička může být za okrajem posunuté osy - detail zůstane na obrazovce.
    final vlevo = math.min(doprava, obrazovka.width - _sirka - Insets.sm);
    final celkem = vytizeni.celkem;
    return Stack(
      children: [
        Positioned(
          left: math.max(Insets.sm, vlevo),
          top: kotva.bottom + 6,
          width: _sirka,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              key: const Key('plan-detail-vytizeni'),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.hairline2),
                boxShadow: [
                  BoxShadow(
                    color:
                        (context.isDarkMode ? Colors.black : AppColors.primary)
                            .withValues(alpha: context.isDarkMode ? 0.5 : 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${denSNazvem(den)} · vytížení',
                      style: AppTextStyles.metaSmall.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    for (final (dilna, radek) in vytizeni.dilny)
                      _RadekDetailu(
                        key: Key('plan-vytizeni-${dilna.kod}'),
                        radek: radek,
                      ),
                    const SizedBox(height: Insets.sm),
                    Divider(height: 1, color: palette.hairline),
                    const SizedBox(height: 6),
                    Row(
                      key: const Key('plan-vytizeni-celkem'),
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          celkem.nazev,
                          style: AppTextStyles.metaSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        // Dlouhá čísla se raději zmenší, než aby přetekla.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${celkem.hodinyZKapacity} · ${celkem.procentText}',
                              style: AppTextStyles.monoLabel.copyWith(
                                fontSize: 11.5,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dílna v detailu: pruh je oříznutý na 100 %, text ukazuje skutečné procento.
class _RadekDetailu extends StatelessWidget {
  const _RadekDetailu({super.key, required this.radek});

  final RadekVytizeni radek;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _barvyVytizeni(context, radek.uroven);
    final vypln = radek.kapacita == 0 && radek.hodin > 0
        ? 1.0
        : math.min(radek.procent ?? 0, 100) / 100;
    final zvyraznit =
        radek.uroven == UrovenVytizeni.pres ||
        radek.uroven == UrovenVytizeni.plno;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                radek.nazev,
                style: AppTextStyles.metaSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: palette.muted2,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${hodinyText(radek.hodin)} h · ${radek.procentText}',
                    style: AppTextStyles.monoLabel.copyWith(
                      fontSize: 11.5,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                      color: zvyraznit ? barvy.text : palette.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: vypln,
              backgroundColor: palette.background,
              color: barvy.segment,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barvy pruhů podle stavu úkonu.
({Color pozadi, Color okraj, Color text}) _barvyPruhu(
  BuildContext context,
  StavPruhu stav,
) {
  final palette = context.palette;
  final tmava = context.isDarkMode;
  final zelena = tmava ? const Color(0xFF81C784) : AppColors.heliosGreen;
  final cervena = tmava ? const Color(0xFFFF7A7A) : AppColors.danger;
  return switch (stav) {
    StavPruhu.planovano => (
      pozadi: palette.background,
      okraj: palette.hairline2,
      text: palette.text,
    ),
    StavPruhu.probiha => (
      pozadi: AppColors.accent.withValues(alpha: 0.12),
      okraj: AppColors.accent,
      text: palette.text,
    ),
    StavPruhu.hotovo => (
      pozadi: zelena.withValues(alpha: 0.1),
      okraj: zelena.withValues(alpha: 0.5),
      text: zelena,
    ),
    StavPruhu.poTerminu => (
      pozadi: cervena.withValues(alpha: 0.08),
      okraj: cervena,
      text: palette.text,
    ),
  };
}

/// Co která barva pruhu znamená.
class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      key: const Key('plan-legenda'),
      spacing: Insets.md,
      runSpacing: Insets.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          key: const Key('plan-legenda-vytizeni'),
          padding: const EdgeInsets.only(right: Insets.md),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: palette.hairline2)),
          ),
          child: Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Vytížení',
                style: AppTextStyles.metaSmall.copyWith(color: palette.text),
              ),
              for (final (uroven, popisek) in const [
                (UrovenVytizeni.nizke, '< 50 %'),
                (UrovenVytizeni.ok, '50–84'),
                (UrovenVytizeni.plno, '85–100'),
                (UrovenVytizeni.pres, '> 100'),
              ])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _barvyVytizeni(context, uroven).pozadi,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    popisek,
                    style: AppTextStyles.monoLabel.copyWith(
                      fontSize: 11.5,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                      color: _barvyVytizeni(context, uroven).naPozadi,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final (stav, nazev) in const [
          (StavPruhu.planovano, 'Plánováno'),
          (StavPruhu.probiha, 'Probíhá'),
          (StavPruhu.hotovo, 'Hotovo'),
          (StavPruhu.poTerminu, 'Po termínu'),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 11,
                decoration: BoxDecoration(
                  color: _barvyPruhu(context, stav).pozadi,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _barvyPruhu(context, stav).okraj),
                ),
              ),
              const SizedBox(width: Insets.xs),
              Text(
                nazev,
                style: AppTextStyles.metaSmall.copyWith(color: palette.text),
              ),
            ],
          ),
      ],
    );
  }
}

bool _jeDnes(DateTime d, DateTime dnes) =>
    d.year == dnes.year && d.month == dnes.month && d.day == dnes.day;

/// Řádek zakázky: vlevo vůz a zákazník, vpravo pruhy úkonů přes dny plánu.
class _Radek extends ConsumerWidget {
  const _Radek({
    required this.polozka,
    required this.dny,
    required this.levy,
    required this.sirky,
    required this.onOpenOrder,
  });

  final PolozkaPlanu polozka;
  final List<DateTime> dny;
  final double levy;
  final List<double> sirky;
  final ValueChanged<String> onOpenOrder;

  /// Šířka sloupců od [od] do [do_] (bez něj).
  double _delka(int od, int do_) =>
      sirky.sublist(od, do_).fold(0.0, (soucet, s) => soucet + s);

  static const _vyska = 102.0;

  /// O kolik je řádek vyšší s tlačítky Zahájit a Dokončit.
  static const _vyskaAkci = 36.0;

  /// Výška pruhu a krok mezi linkami pod sebou.
  static const _vyskaPruhu = 30.0;
  static const _krokLinky = 34.0;

  /// Nad pruhy odsazení, pod nimi pás, kde se klepnutím přidá další úkon.
  static const _nadPruhy = 8.0;
  static const _pasPridani = 26.0;

  /// Na užším pruhu by se kód laku a název úkonu nevešly.
  static const _sirkaProKod = 130.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final dnes = ref.watch(dnesProvider);
    final plan = polozka.plan;
    final (:pruhy, :linek) = pruhyVOse(plan?.ukony ?? const [], dny);
    // Plán i dílenský stav mění, kdo u pobočky v plánovači plánuje. Detail
    // zakázky jen s právem k jejímu pořadači.
    final smi = ref.watch(smiPlanovatProvider(polozka.pobockaKod));
    final zakazkaRadku = polozka.zakazka;
    final akce = smi && zakazkaRadku != null
        ? akcePrubehu(plan, zakazkaRadku.historieStavu)
        : (zahajit: null, dokoncit: null);
    final maAkce = akce.zahajit != null || akce.dokoncit != null;
    final detail = ref.watch(smiCistProvider(polozka.zakazka?.poradac?.kod));
    // Klepnutí na den přidá úkon s tím dnem předvyplněným.
    void pridej(DateTime den) => naplanovatKlempirnu(
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
      height: math.max(
        _vyska + (maAkce ? _vyskaAkci : 0),
        _nadPruhy + linek * _krokLinky + _pasPridani,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: levy,
            child: InkWell(
              key: Key('plan-zakazka-${polozka.zakazkaId}'),
              onTap: detail ? () => onOpenOrder(polozka.zakazkaId) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.base),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
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
                        ),
                        // Kód barvy vozu z Heliosu - nezkracuje se.
                        if (polozka.barva case final barva?) ...[
                          const SizedBox(width: Insets.sm),
                          Tooltip(
                            message: barva.popis,
                            child: KodLaku(
                              key: Key('plan-barva-${polozka.zakazkaId}'),
                              kod: barva.kod,
                            ),
                          ),
                        ],
                      ],
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
                      if (maAkce) ...[
                        const SizedBox(height: Insets.xs),
                        _AkcePrubehu(
                          zakazka: zakazka,
                          zahajit: akce.zahajit,
                          dokoncit: akce.dokoncit,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: _delka(0, dny.length),
            child: Stack(
              children: [
                Row(
                  children: [
                    for (final (i, d) in dny.indexed)
                      Container(
                        width: sirky[i],
                        decoration: BoxDecoration(
                          color: _jeDnes(d, dnes)
                              ? AppColors.accent.withValues(alpha: 0.05)
                              : jeVikend(d)
                              ? palette.background
                              : null,
                          border: Border(
                            left: i > 0 && i % 7 == 0
                                ? BorderSide(color: palette.hairline2, width: 2)
                                : BorderSide(color: palette.hairline),
                          ),
                        ),
                        child: InkWell(
                          key: Key('plan-den-${polozka.zakazkaId}-${d.day}'),
                          // V sobotu a v neděli je zavřeno, úkon tam nezačíná.
                          onTap: smi && !jeVikend(d) ? () => pridej(d) : null,
                          child: smi && !jeVikend(d)
                              ? Align(
                                  // S plánem dole v pásu pod pruhy.
                                  alignment: plan == null
                                      ? Alignment.center
                                      : Alignment.bottomCenter,
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                    color: palette.muted.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                // Plán mimo zobrazené dny - aspoň kdy je.
                if (plan != null && pruhy.isEmpty)
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
                for (final p in pruhy)
                  Positioned(
                    left: _delka(0, p.prvni) + 4,
                    width: _delka(p.prvni, p.posledni + 1) - 8,
                    top: _nadPruhy + p.linka * _krokLinky,
                    height: _vyskaPruhu,
                    child: _Pruh(
                      polozka: polozka,
                      smi: smi,
                      ukon: p.ukon,
                      stav: stavPruhu(polozka, p.ukon, dnes),
                      sKodem:
                          _delka(p.prvni, p.posledni + 1) - 8 >= _sirkaProKod,
                      useknutyZleva: p.ukon.od.isBefore(dny[p.prvni]),
                      useknutyZprava: p.ukon.do_.isAfter(dny[p.posledni]),
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

/// Úkon na ose v barvě podle stavu.
class _Pruh extends ConsumerWidget {
  const _Pruh({
    required this.polozka,
    required this.ukon,
    required this.stav,
    required this.sKodem,
    required this.useknutyZleva,
    required this.useknutyZprava,
    this.smi = true,
  });

  final PolozkaPlanu polozka;
  final UkonPlanu ukon;
  final StavPruhu stav;

  /// Kód laku se na pruh vejde (a jde o lakovnu - viz build).
  final bool sKodem;

  /// Jen čtení - klepnutím se úkon neotevře k úpravě.
  final bool smi;
  final bool useknutyZleva;
  final bool useknutyZprava;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barvy = _barvyPruhu(context, stav);
    final poznamka = ukon.poznamka.trim();
    final hotovo = stav == StavPruhu.hotovo;
    const r = Radius.circular(8);

    return Material(
      color: barvy.pozadi,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: barvy.okraj),
        borderRadius: BorderRadius.horizontal(
          left: useknutyZleva ? Radius.zero : r,
          right: useknutyZprava ? Radius.zero : r,
        ),
      ),
      child: InkWell(
        key: Key('plan-pruh-${polozka.zakazkaId}-${ukon.id}'),
        onTap: smi
            ? () => naplanovatKlempirnu(
                context,
                ref,
                zakazkaId: polozka.zakazkaId,
                spz: polozka.spz,
                plan: polozka.plan,
                ukon: ukon,
                barva: polozka.barva,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          child: Row(
            children: [
              if (hotovo)
                Icon(Icons.check_circle_rounded, size: 15, color: barvy.text)
              else
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stav == StavPruhu.probiha ? barvy.okraj : null,
                    border: Border.all(
                      color: stav == StavPruhu.planovano
                          ? context.palette.muted
                          : barvy.okraj,
                      width: 1.5,
                    ),
                  ),
                ),
              const SizedBox(width: Insets.xs),
              // Kód laku jen na lakovně - jinde by překážel názvu úkonu.
              if (polozka.kodLaku case final kod?
                  when sKodem && ukon.typ.jeLakovna) ...[
                // Na krátkém pruhu se raději zmenší, než aby přetekl.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: KodLaku(kod: kod, naPruhu: true),
                  ),
                ),
                const SizedBox(width: Insets.sm),
              ],
              Expanded(
                child: Text(
                  poznamka.isEmpty
                      ? ukon.typ.nazev
                      : '${ukon.typ.nazev} · $poznamka',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metaSmall.copyWith(
                    color: barvy.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (ukon.aw == null && !hotovo) ...[
                const SizedBox(width: Insets.xs),
                // Na krátkém pruhu se raději zkrátí.
                Flexible(
                  child: Text(
                    'doplnit AW',
                    key: Key('plan-bez-aw-${ukon.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.metaSmall.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC98200),
                    ),
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
  const _Chyba({super.key, required this.text, this.onZnovu});

  final String text;

  /// Bez něj tlačítko Zkusit znovu chybí (plánovač bez přístupu).
  final VoidCallback? onZnovu;

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
            if (onZnovu != null)
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

/// Zahájit a Dokončit stejně jako v průběhu opravy v detailu zakázky: zahajuje
/// se další úkon na řadě, dokončuje se krok, který probíhá. Dvě tlačítka se
/// v úzkém sloupci (telefon) dělí o šířku, text se případně zmenší.
class _AkcePrubehu extends ConsumerWidget {
  const _AkcePrubehu({
    required this.zakazka,
    required this.zahajit,
    required this.dokoncit,
  });

  final ServiceOrder zakazka;
  final PolozkaOsy? zahajit;
  final PolozkaOsy? dokoncit;

  Future<void> _dokonci(
    BuildContext context,
    WidgetRef ref,
    String zaznamId,
  ) async {
    final hotovo = await ref
        .read(orderActionsProvider.notifier)
        .dokonciStav(zakazka.id, zaznamId);
    if (hotovo || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Krok se nepodařilo dokončit.')),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zaneprazdneno = ref.watch(orderActionsProvider).isLoading;
    final zaznamId = dokoncit?.zaznam?.id;
    final ukon = zahajit?.ukon;
    final obe = zaznamId != null && ukon != null;
    Widget popisek(String text) =>
        FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
    const vnitrek = EdgeInsets.symmetric(horizontal: Insets.sm);
    final tlacitka = <Widget>[
      if (zaznamId != null)
        Tooltip(
          message: 'Dokončit: ${dokoncit!.nazev}',
          child: FilledButton(
            key: Key('plan-radek-dokoncit-${zakazka.id}'),
            onPressed: zaneprazdneno
                ? null
                : () => _dokonci(context, ref, zaznamId),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: vnitrek,
              // Tmavomodrá by na tmavém pozadí zanikla.
              backgroundColor: context.isDarkMode
                  ? AppColors.accent
                  : AppColors.primary,
              foregroundColor: Colors.white,
              textStyle: AppTextStyles.chip,
            ),
            child: popisek('Dokončit'),
          ),
        ),
      if (ukon != null)
        Tooltip(
          message: 'Zahájit: ${zahajit!.nazev}',
          child: OutlinedButton(
            key: Key('plan-radek-zahajit-${zakazka.id}'),
            onPressed: () =>
                pridatStavZakazce(context, ref, zakazka, ukon: ukon.typ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: vnitrek,
              textStyle: AppTextStyles.chip,
            ),
            child: popisek('Zahájit'),
          ),
        ),
    ];
    return Row(
      children: [
        for (final (i, t) in tlacitka.indexed) ...[
          if (i > 0) const SizedBox(width: Insets.xs),
          obe ? Expanded(child: t) : t,
        ],
      ],
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
      OrderFilter.ja: 'Já',
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
                    final filtr = ref.read(planFiltrProvider.notifier);
                    filtr.state = OrderFilter(mujEmail: filtr.state.mujEmail);
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
