import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../domain/monitoring.dart';
import 'monitoring_providers.dart';

/// Od jaké šířky jsou karty po dvou vedle sebe a uživatelé jako tabulka.
const _sirkaVedleSebe = 840.0;

String _cislo(int n) => NumberFormat.decimalPattern('cs_CZ').format(n);

String _lidi(int n) =>
    '$n ${n == 1
        ? 'člověk'
        : n < 5 && n > 1
        ? 'lidé'
        : 'lidí'}';

/// Barvy monitoringu - stejné jako na webu (pásma vytížení plánovače).
class _Barvy {
  const _Barvy._({
    required this.pruhPozadi,
    required this.stopa,
    required this.seda,
    required this.stara,
    required this.klient,
  });

  final Color pruhPozadi;
  final Color stopa;
  final Color seda;
  final Color stara;

  /// Klient -> (pozadí, text) štítku.
  final Map<String, (Color, Color)> klient;

  factory _Barvy.of(BuildContext context) {
    final t = context.isDarkMode;
    return _Barvy._(
      pruhPozadi: t ? const Color(0x294599FE) : const Color(0xFFEAF2FC),
      stopa: t ? const Color(0x14FFFFFF) : const Color(0xFFEEF2F4),
      seda: t ? const Color(0x3DFFFFFF) : const Color(0xFFD3DFE4),
      stara: t ? const Color(0xFFE8A93A) : const Color(0xFFB8740A),
      klient: {
        'Aplikace': t
            ? (const Color(0x294599FE), const Color(0xFF8CC0FF))
            : (const Color(0xFFEAF2FC), const Color(0xFF1F4F8F)),
        'Web': t
            ? (const Color(0x295FD38D), const Color(0xFF5FD38D))
            : (const Color(0xFFE3F5EA), const Color(0xFF1B6E3C)),
        'Plánovač': t
            ? (const Color(0x29E8A93A), const Color(0xFFE8A93A))
            : (const Color(0xFFFFF1D6), const Color(0xFF8A5A00)),
      },
    );
  }
}

/// Monitoring používání (Admin › Monitoring, jen admin) - stejné jako
/// stránka Monitoring na webu: kolik lidí RenoWorkshop používá, kdy a co
/// v něm dělají. Klepnutím na uživatele jeho časová osa.
class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final dni = ref.watch(obdobiMonitoringuProvider);
    final prehled = ref.watch(monitoringProvider(dni));

    return ColoredBox(
      color: palette.background,
      child: LayoutBuilder(
        builder: (context, rozmery) {
          final siroke = rozmery.maxWidth >= _sirkaVedleSebe;
          return RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(monitoringProvider(dni).future),
            child: ListView(
              key: const Key('monitoring'),
              padding: EdgeInsets.fromLTRB(
                siroke ? Insets.xl : Insets.lg,
                Insets.base,
                siroke ? Insets.xl : Insets.lg,
                Insets.giant,
              ),
              children: [
                _Obdobi(dni: dni, prehled: prehled.valueOrNull),
                const SizedBox(height: Insets.base),
                ...prehled.when(
                  skipLoadingOnReload: true,
                  loading: () => const [
                    Padding(
                      padding: EdgeInsets.all(Insets.giant),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (chyba, _) => [
                    Padding(
                      padding: const EdgeInsets.all(Insets.xl),
                      child: Text(
                        chyba is ServiceOrderException
                            ? chyba.message
                            : 'Monitoring se nepodařilo načíst.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  data: (p) => _obsah(context, p, siroke: siroke, dni: dni),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _obsah(
    BuildContext context,
    PrehledMonitoringu p, {
    required bool siroke,
    required int dni,
  }) {
    Widget dva(Widget a, Widget b) => siroke
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: a),
                const SizedBox(width: Insets.xl),
                Expanded(child: b),
              ],
            ),
          )
        : Column(
            children: [
              a,
              const SizedBox(height: Insets.xl),
              b,
            ],
          );

    return [
      _Ukazatele(p: p),
      const SizedBox(height: Insets.xl),
      dva(
        _Karta(
          nadpis: 'Lidé a návštěvy po dnech',
          child: _GrafDnu(p: p),
        ),
        _Karta(
          nadpis: 'Kdy se pracuje',
          popis: 'Požadavky podle dne v týdnu a hodiny',
          child: _MrizkaHodin(p: p),
        ),
      ),
      const SizedBox(height: Insets.xl),
      _Karta(
        nadpis: 'Uživatelé',
        popis:
            'Návštěva = práce bez pauzy delší než ${p.pauzaNavstevy} min. '
            'Klepnutím otevřete, co dělal.',
        child: _Uzivatele(p: p, tabulka: siroke, dni: dni),
      ),
      const SizedBox(height: Insets.xl),
      dva(
        _Karta(
          nadpis: 'Co dělají',
          popis: 'Podle požadavků na službu; zápisy jsou zvýrazněné',
          child: _Pruhy(polozky: p.akce),
        ),
        _Karta(
          nadpis: 'Obrazovky',
          popis: 'Kam se v aplikaci a na webu chodí',
          child: _Pruhy(
            polozky: p.obrazovky,
            prazdne: p.dni > 30
                ? 'Obrazovky se v logu drží jen 30 dní.'
                : 'Zatím žádné obrazovky v logu.',
          ),
        ),
      ),
      const SizedBox(height: Insets.xl),
      dva(
        _Karta(
          nadpis: 'Verze aplikace',
          popis: 'Poslední verze u každého uživatele aplikace',
          child: _Pruhy(
            polozky: p.verze,
            verze: true,
            prazdne: 'Nikdo v tomto období aplikaci nepoužil.',
          ),
        ),
        _Karta(
          nadpis: 'Bez aktivity v období',
          popis: 'Účty, které mají práva, ale nepřišly',
          child: _Neaktivni(p: p),
        ),
      ),
      const SizedBox(height: Insets.xl),
      _Karta(
        nadpis: 'Poslední chyby',
        popis: 'Ze služby i z aplikace a webu; vypršené přihlášení (401) ne',
        child: _Chyby(p: p),
      ),
    ];
  }
}

class _Obdobi extends ConsumerWidget {
  const _Obdobi({required this.dni, required this.prehled});

  final int dni;
  final PrehledMonitoringu? prehled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final p = prehled;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Insets.lg,
      runSpacing: Insets.sm,
      children: [
        Text(
          p == null
              ? 'Z logu přístupů a událostí'
              : '${AppDateFormat.dayMonth(p.od)} – ${AppDateFormat.dayMonth(p.do_)}'
                    ' · z logu přístupů a událostí',
          style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
        ),
        SegmentedButton<int>(
          key: const Key('monitoring-obdobi'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final o in obdobiMonitoringu)
              ButtonSegment(value: o.dni, label: Text(o.popisek)),
          ],
          selected: {dni},
          onSelectionChanged: (v) =>
              ref.read(obdobiMonitoringuProvider.notifier).state = v.first,
        ),
      ],
    );
  }
}

class _Karta extends StatelessWidget {
  const _Karta({required this.nadpis, required this.child, this.popis});

  final String nadpis;
  final String? popis;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.lg,
        Insets.xl,
        Insets.xl,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            nadpis,
            style: AppTextStyles.cardBody.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (popis != null) ...[
            const SizedBox(height: 2),
            Text(
              popis!,
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
          ],
          const SizedBox(height: Insets.base),
          child,
        ],
      ),
    );
  }
}

class _Ukazatele extends StatelessWidget {
  const _Ukazatele({required this.p});

  final PrehledMonitoringu p;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final polozky = [
      ('Aktivní uživatelé', _cislo(p.lidi), 'z ${_cislo(p.ucty)} účtů', false),
      (
        'Návštěvy',
        _cislo(p.navstevy),
        p.lidi == 0
            ? '—'
            : '${(p.navstevy / p.lidi).toStringAsFixed(1).replaceAll('.', ',')} na člověka',
        false,
      ),
      ('Zápisy', _cislo(p.zapisy), 'stavy, fotky, plán, poznámky…', false),
      (
        'Chyby',
        _cislo(p.chybyCelkem),
        '${_cislo(p.chybySluzby)} služba · ${_cislo(p.chybyKlientu)} aplikace a web',
        p.chybyCelkem > 0,
      ),
      (
        'Průměrná odezva',
        p.prumerMs == null ? '—' : '${_cislo(p.prumerMs!)} ms',
        '${_cislo(p.pozadavky)} požadavků',
        false,
      ),
    ];
    return LayoutBuilder(
      builder: (context, rozmery) {
        final sloupcu = math.max(2, math.min(5, rozmery.maxWidth ~/ 170));
        final sirka =
            (rozmery.maxWidth - (sloupcu - 1) * Insets.base) / sloupcu;
        return Wrap(
          spacing: Insets.base,
          runSpacing: Insets.base,
          children: [
            for (final (popisek, hodnota, pod, varovani) in polozky)
              Container(
                width: sirka,
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.hairline),
                  boxShadow: palette.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      popisek,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hodnota,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: varovani ? AppColors.danger : palette.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      pod,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GrafDnu extends StatelessWidget {
  const _GrafDnu({required this.p});

  final PrehledMonitoringu p;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    final max = p.poDnech.fold(1, (m, d) => math.max(m, d.navstevy));
    final husty = p.poDnech.length > 14;
    final styl = AppTextStyles.metaSmall.copyWith(
      color: palette.muted2,
      fontSize: 10.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in p.poDnech)
                Expanded(
                  child: Tooltip(
                    message:
                        '${AppDateFormat.dayMonth(d.datum)}: ${d.lidi} lidí, '
                        '${d.navstevy} návštěv, ${d.zapisy} zápisů',
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: husty ? 0.5 : 3,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!husty)
                            Text(
                              d.navstevy > 0 ? '${d.navstevy}' : '',
                              style: styl,
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: 130 * d.navstevy / max,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: barvy.pruhPozadi,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                            child: FractionallySizedBox(
                              heightFactor: d.navstevy == 0
                                  ? 0
                                  : math.min(1, d.lidi / d.navstevy),
                              widthFactor: 1,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 14,
                            child: Text(
                              husty
                                  ? (d.datum.day == 1
                                        ? AppDateFormat.dayMonth(d.datum)
                                        : '')
                                  : p.poDnech.length > 8
                                  ? '${d.datum.day}.'
                                  : AppDateFormat.dayMonth(d.datum),
                              style: styl,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            _Legenda(barva: barvy.pruhPozadi, text: 'návštěvy'),
            const SizedBox(width: Insets.lg),
            const _Legenda(barva: AppColors.accent, text: 'lidé'),
          ],
        ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.barva, required this.text});

  final Color barva;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: barva,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: AppTextStyles.metaSmall.copyWith(color: context.palette.muted),
      ),
    ],
  );
}

class _MrizkaHodin extends StatelessWidget {
  const _MrizkaHodin({required this.p});

  final PrehledMonitoringu p;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    final (:hodiny, :bunky) = mrizkaHodin(p.hodiny);
    final styl = AppTextStyles.metaSmall.copyWith(
      color: palette.muted,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    );
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 26),
            for (final h in hodiny)
              Expanded(
                child: Text(
                  h.isEven ? '$h' : '',
                  textAlign: TextAlign.center,
                  style: styl,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        for (final (den, radek) in bunky.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(width: 26, child: Text(dnyTydne[den], style: styl)),
                for (final (i, b) in radek.indexed)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${dnyTydne[den]} ${hodiny[i]}:00 – '
                          '${_cislo(b.pozadavky)} požadavků, ${b.lidi} lidí',
                      child: Container(
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: b.pozadavky == 0
                              ? barvy.stopa
                              : AppColors.accent.withValues(
                                  alpha: 0.15 + b.sila * 0.85,
                                ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StitekKlienta extends StatelessWidget {
  const _StitekKlienta(this.popis);

  final String popis;

  @override
  Widget build(BuildContext context) {
    final barvy = _Barvy.of(context);
    final (pozadi, text) =
        barvy.klient[popis] ?? (barvy.stopa, context.palette.muted2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: pozadi,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        popis,
        style: AppTextStyles.metaSmall.copyWith(
          color: text,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Uzivatele extends StatelessWidget {
  const _Uzivatele({required this.p, required this.tabulka, required this.dni});

  final PrehledMonitoringu p;
  final bool tabulka;
  final int dni;

  void _otevri(BuildContext context, UzivatelMonitoringu u) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              OsaUzivateleScreen(email: u.email, jmeno: u.jmeno, dni: dni),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (p.uzivatele.isEmpty) {
      return Text(
        'V tomto období nikdo nepřišel.',
        style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
      );
    }
    final nejnovejsi = p.nejnovejsiVerze;
    final hlavicka = AppTextStyles.metaSmall.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w600,
    );
    final telo = AppTextStyles.cardBody.copyWith(color: palette.text);
    final male = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    final barvy = _Barvy.of(context);

    Widget verze(UzivatelMonitoringu u) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          u.verze ?? '—',
          style: telo.copyWith(
            color: u.verze != null && u.verze != nejnovejsi
                ? barvy.stara
                : u.verze == null
                ? palette.muted
                : palette.text,
            fontWeight: u.verze != null && u.verze != nejnovejsi
                ? FontWeight.w600
                : null,
          ),
        ),
        if (u.zarizeni != null) Text(u.zarizeni!, style: male),
      ],
    );
    Widget klienti(UzivatelMonitoringu u) => Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [for (final k in u.klienti) _StitekKlienta(popisKlienta(k))],
    );
    Widget cislo(int n, {bool chyba = false}) => Text(
      _cislo(n),
      textAlign: TextAlign.right,
      style: telo.copyWith(
        color: chyba && n > 0 ? AppColors.danger : null,
        fontWeight: chyba && n > 0 ? FontWeight.w600 : null,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    String naposledy(UzivatelMonitoringu u) => u.naposledy == null
        ? '—'
        : AppDateFormat.relativeDateTime(u.naposledy!);

    if (tabulka) {
      Widget radek(List<Widget> bunky, {VoidCallback? onTap, Key? key}) =>
          InkWell(
            key: key,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: Insets.sm,
                horizontal: Insets.xs,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 26, child: bunky[0]),
                  Expanded(flex: 18, child: bunky[1]),
                  Expanded(flex: 16, child: bunky[2]),
                  Expanded(flex: 7, child: bunky[3]),
                  Expanded(flex: 8, child: bunky[4]),
                  Expanded(flex: 8, child: bunky[5]),
                  Expanded(flex: 7, child: bunky[6]),
                  const SizedBox(width: Insets.base),
                  Expanded(flex: 14, child: bunky[7]),
                ],
              ),
            ),
          );
      return Column(
        children: [
          radek([
            Text('Uživatel', style: hlavicka),
            Text('Kde', style: hlavicka),
            Text('Verze aplikace', style: hlavicka),
            Text('Dní', style: hlavicka, textAlign: TextAlign.right),
            Text('Návštěv', style: hlavicka, textAlign: TextAlign.right),
            Text('Zápisů', style: hlavicka, textAlign: TextAlign.right),
            Text('Chyb', style: hlavicka, textAlign: TextAlign.right),
            Text('Naposledy', style: hlavicka),
          ]),
          for (final u in p.uzivatele)
            radek(
              key: Key('monitoring-uzivatel-${u.email}'),
              onTap: () => _otevri(context, u),
              [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.zobrazeneJmeno,
                      style: telo.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (u.jmeno != null) Text(u.email, style: male),
                  ],
                ),
                klienti(u),
                verze(u),
                cislo(u.dni),
                cislo(u.navstevy),
                cislo(u.zapisy),
                cislo(u.chyby, chyba: true),
                Text(naposledy(u), style: telo),
              ],
            ),
        ],
      );
    }

    // Telefon: uživatel jako řádek seznamu, čísla pod jménem.
    return Column(
      children: [
        for (final u in p.uzivatele)
          InkWell(
            key: Key('monitoring-uzivatel-${u.email}'),
            onTap: () => _otevri(context, u),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Insets.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.hairline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.zobrazeneJmeno,
                                overflow: TextOverflow.ellipsis,
                                style: telo.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Text(naposledy(u), style: male),
                          ],
                        ),
                        const SizedBox(height: 4),
                        klienti(u),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            style: male,
                            children: [
                              TextSpan(
                                text:
                                    '${u.dni} dní · ${_cislo(u.navstevy)} návštěv · '
                                    '${_cislo(u.zapisy)} zápisů',
                              ),
                              if (u.chyby > 0)
                                TextSpan(
                                  text: ' · ${_cislo(u.chyby)} chyb',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (u.verze != null)
                                TextSpan(
                                  text: ' · ${u.verze}',
                                  style: u.verze != nejnovejsi
                                      ? TextStyle(
                                          color: barvy.stara,
                                          fontWeight: FontWeight.w600,
                                        )
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: palette.muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Pruhy extends StatefulWidget {
  const _Pruhy({
    required this.polozky,
    this.prazdne = 'Zatím nic.',
    this.verze = false,
  });

  final List<PolozkaPruhu> polozky;
  final String prazdne;

  /// Verze aplikace - starší než nejnovější oranžově, počet jako lidé.
  final bool verze;

  @override
  State<_Pruhy> createState() => _PruhyState();
}

class _PruhyState extends State<_Pruhy> {
  bool _vse = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    final polozky = widget.polozky;
    if (polozky.isEmpty) {
      return Text(
        widget.prazdne,
        style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
      );
    }
    final max = polozky.fold(1, (m, x) => math.max(m, x.pocet));
    final vidim = _vse ? polozky : polozky.take(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final x in vidim)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: x.text,
                          children: [
                            if (x.stitek != null)
                              TextSpan(
                                text: '  ${x.stitek}',
                                style: AppTextStyles.metaSmall.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                          ],
                        ),
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.text,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Text(
                      widget.verze
                          ? _lidi(x.lidi)
                          : '${_cislo(x.pocet)} · ${_lidi(x.lidi)}',
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: math.max(0.02, x.pocet / max),
                    minHeight: 6,
                    backgroundColor: barvy.stopa,
                    color: x.zvyraznit
                        ? AppColors.accent
                        : widget.verze
                        ? barvy.stara
                        : barvy.seda,
                  ),
                ),
              ],
            ),
          ),
        if (polozky.length > 12)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _vse = !_vse),
              child: Text(_vse ? 'Méně' : 'Všech ${polozky.length}'),
            ),
          ),
      ],
    );
  }
}

class _Neaktivni extends StatelessWidget {
  const _Neaktivni({required this.p});

  final PrehledMonitoringu p;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final male = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    if (p.neaktivni.isEmpty) return Text('Přišli všichni.', style: male);
    return Column(
      children: [
        for (final u in p.neaktivni)
          Container(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.zobrazeneJmeno,
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (u.jmeno != null) Text(u.email, style: male),
                    ],
                  ),
                ),
                Text(
                  u.naposledy == null
                      ? 'nikdy nepřihlášen'
                      : 'přihlášen ${AppDateFormat.date(u.naposledy!)}',
                  style: male,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chyby extends StatelessWidget {
  const _Chyby({required this.p});

  final PrehledMonitoringu p;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final male = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    if (p.chyby.isEmpty) return Text('Žádné chyby.', style: male);
    return Column(
      children: [
        for (final c in p.chyby)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (c.kdy != null) AppDateFormat.dateTime(c.kdy!),
                    c.kdo ?? 'nepřihlášený',
                    c.odkud,
                    ?c.verze,
                  ].join(' · '),
                  style: male,
                ),
                const SizedBox(height: 2),
                Text(
                  [c.co, ?c.zakazka].join(' · '),
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (c.zprava != null)
                  Text(
                    c.zprava!,
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted2,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Časová osa jednoho uživatele - co otevřel a co zapsal, nejnovější
/// nahoře. Opakování (obnova seznamu) je sbalené do jednoho řádku.
class OsaUzivateleScreen extends ConsumerWidget {
  const OsaUzivateleScreen({
    super.key,
    required this.email,
    required this.dni,
    this.jmeno,
  });

  final String email;
  final String? jmeno;
  final int dni;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final klic = (email: email, dni: dni);
    final osa = ref.watch(osaMonitoringuProvider(klic));
    final male = AppTextStyles.metaSmall.copyWith(color: palette.muted);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              jmeno ?? email,
              style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
            ),
            if (jmeno != null) Text(email, style: male),
          ],
        ),
      ),
      body: osa.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (chyba, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Text(
              chyba is ServiceOrderException
                  ? chyba.message
                  : 'Časovou osu se nepodařilo načíst.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (o) => o.polozky.isEmpty
            ? Center(child: Text('V tomto období nic.', style: male))
            : RefreshIndicator.adaptive(
                onRefresh: () =>
                    ref.refresh(osaMonitoringuProvider(klic).future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    0,
                    Insets.lg,
                    Insets.giant,
                  ),
                  itemCount: o.polozky.length + (o.zkracena ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == o.polozky.length) {
                      return Padding(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Text(
                          'Zobrazeno jen posledních 1 500 záznamů – zkraťte období.',
                          style: male,
                        ),
                      );
                    }
                    final x = o.polozky[i];
                    final predchozi = i == 0 ? null : o.polozky[i - 1].kdy;
                    final novyDen =
                        predchozi == null ||
                        !DateUtils.isSameDay(predchozi, x.kdy);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (novyDen)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: Insets.lg,
                              bottom: Insets.xs,
                            ),
                            child: Text(
                              AppDateFormat.date(x.kdy),
                              style: AppTextStyles.cardBody.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        _RadekOsy(x),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _RadekOsy extends StatelessWidget {
  const _RadekOsy(this.x);

  final PolozkaOsy x;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final male = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    final chyba = x.druh == DruhOsy.chyba;
    final cas =
        x.pocet > 1 && AppDateFormat.time(x.od) != AppDateFormat.time(x.kdy)
        ? '${AppDateFormat.time(x.od)}–${AppDateFormat.time(x.kdy)}'
        : AppDateFormat.time(x.kdy);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(cas, style: male)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: x.popis,
                    children: [
                      if (x.pocet > 1)
                        TextSpan(text: ' ×${x.pocet}', style: male),
                    ],
                  ),
                  style: AppTextStyles.cardBody.copyWith(
                    color: chyba ? AppColors.danger : palette.text,
                    fontWeight: x.druh == DruhOsy.zapis || chyba
                        ? FontWeight.w600
                        : null,
                  ),
                ),
                Text(
                  [x.druh.popis, ?x.zakazka, ?x.chyba].join(' · '),
                  style: male,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          _StitekKlienta(popisKlienta(x.klient)),
        ],
      ),
    );
  }
}
