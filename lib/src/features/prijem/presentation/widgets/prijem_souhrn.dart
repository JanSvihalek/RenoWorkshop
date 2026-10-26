import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/log_udalosti_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../fotodokumentace/domain/entities/fotka.dart';
import '../../../fotodokumentace/presentation/controllers/fotky_providers.dart';
import '../../../fotodokumentace/presentation/prace_s_dokumenty.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../domain/entities/prijem.dart';
import '../controllers/prijem_providers.dart';
import 'dezen_pneu.dart';
import 'prijem_karta.dart';

/// Žlutá „končí brzy" - jako doporučená výměna dezénu.
const _zluta = Color(0xFFC98200);

/// Kolik minut kolem příjmu se fotka počítá jako fotka z příjmu.
const _rezervaFotek = Duration(minutes: 10);

/// Sekce Příjem v detailu zakázky (Jan 26. 10. 2026): místo celého
/// checklistu souhrn - stav a kdo, nálezy, dezén pneu, STK, fotky
/// z příjmu; celý checklist sbalený pod odkazem. Jako na webu.
///
/// Nezahájený příjem se zahajuje kartou [PrijemKarta]; bez práva zápisu
/// ([onOtevrit] `null`) je souhrn jen ke čtení.
class PrijemSouhrn extends ConsumerStatefulWidget {
  const PrijemSouhrn({
    super.key,
    required this.orderId,
    this.onOtevrit,
    this.onFotky,
  });

  final String orderId;

  /// Otevře průvodce příjmem; `null` = bez práva zápisu.
  final VoidCallback? onOtevrit;

  /// Otevře fotodokumentaci (klepnutí na náhled).
  final VoidCallback? onFotky;

  @override
  ConsumerState<PrijemSouhrn> createState() => _PrijemSouhrnState();
}

class _PrijemSouhrnState extends ConsumerState<PrijemSouhrn> {
  bool _checklist = false;
  bool _protokolSeOtevira = false;

  Future<void> _otevriProtokol() async {
    if (_protokolSeOtevira) return;
    setState(() => _protokolSeOtevira = true);
    void oznam(String zprava) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(zprava)));
    try {
      final zdroj = ref.read(fotkyDataSourceProvider);
      final protokol = await zdroj.vytvorProtokol(widget.orderId);
      final data = await zdroj.stahniDokument(widget.orderId, protokol.id);
      await ref.read(praceSDokumentyProvider).otevri(protokol.nazev, data);
    } on ServiceOrderException catch (chyba) {
      if (mounted) oznam(chyba.message);
    } on PraceSDokumentyException catch (chyba) {
      if (mounted) oznam(chyba.message);
    } catch (chyba, zasobnik) {
      ref
          .read(logUdalostiProvider)
          .chyba('protokol_neotevren', chyba, zasobnik: zasobnik);
      if (mounted) oznam('Protokol se nepodařilo otevřít.');
    } finally {
      if (mounted) setState(() => _protokolSeOtevira = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final prijem = ref.watch(prijemZakazkyProvider(widget.orderId));
    Widget text(String t) =>
        Text(t, style: AppTextStyles.cardBody.copyWith(color: palette.muted));

    final p = prijem.valueOrNull;
    if (p == null) {
      return DetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('PŘÍJEM VOZIDLA'),
            const SizedBox(height: Insets.sm),
            text(
              prijem.hasError
                  ? 'Příjem se nepodařilo načíst.'
                  : 'Načítám příjem…',
            ),
          ],
        ),
      );
    }
    if (p.stav == StavPrijmu.nezahajen) {
      if (widget.onOtevrit != null) {
        return PrijemKarta(
          orderId: widget.orderId,
          onOtevrit: widget.onOtevrit!,
        );
      }
      return DetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('PŘÍJEM VOZIDLA'),
            const SizedBox(height: Insets.sm),
            text('Nezahájen. Zahajuje ho, kdo má k zakázce zápis.'),
          ],
        ),
      );
    }

    final nalezy = [
      for (final polozka in p.polozky)
        if ((polozka.poznamka ?? '').trim().isNotEmpty) polozka,
    ];
    final dezen = p.polozky.map((x) => x.dezen).nonNulls.firstOrNull;
    final stk = p.polozky
        .where((x) => x.typ == TypKontroly.datum && x.datum != null)
        .firstOrNull;
    final fotky = _fotkyZPrijmu(
      ref.watch(fotkyZakazkyProvider(widget.orderId)).valueOrNull ?? const [],
      p,
    );

    final stav = p.jeDokoncen
        ? [
            'Dokončen',
            if (p.dokoncenoAt != null) AppDateFormat.dateTime(p.dokoncenoAt!),
            ?p.dokoncilKdo,
          ].join(' · ')
        : [
            'Rozpracovaný · ${p.pocetVyplnenych}/${p.pocetPovinnych}',
            if (p.zahajilKdo != null) 'zahájil ${p.zahajilKdo}',
          ].join(' · ');

    return DetailCard(
      key: const Key('prijem-souhrn'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('PŘÍJEM VOZIDLA'),
          const SizedBox(height: Insets.xs),
          Row(
            children: [
              Icon(
                p.jeDokoncen
                    ? Icons.task_alt_rounded
                    : Icons.pending_actions_rounded,
                size: 20,
                color: p.jeDokoncen
                    ? AppColors.readyGreen
                    : AppColors.repairBlue,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  stav,
                  key: const Key('prijem-souhrn-stav'),
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              OutlinedButton.icon(
                key: const Key('prijem-protokol'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _protokolSeOtevira ? null : _otevriProtokol,
                icon: _protokolSeOtevira
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Protokol PDF'),
              ),
              if (widget.onOtevrit != null)
                FilledButton.icon(
                  key: const Key('otevrit-prijem'),
                  // Motiv dává tlačítkům plnou šířku - tady vedle protokolu.
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: widget.onOtevrit,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(
                    p.jeDokoncen ? 'Otevřít příjem' : 'Pokračovat v příjmu',
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              // Dlaždice vedle sebe, když je místo; jinak pod sebou.
              final sloupcu = constraints.maxWidth >= 720
                  ? 3
                  : constraints.maxWidth >= 460
                  ? 2
                  : 1;
              final sirka =
                  (constraints.maxWidth - Insets.md * (sloupcu - 1)) / sloupcu;
              return Wrap(
                spacing: Insets.md,
                runSpacing: Insets.md,
                children: [
                  SizedBox(
                    width: sirka,
                    child: _Nalezy(nalezy: nalezy),
                  ),
                  if (dezen != null)
                    SizedBox(
                      width: sirka,
                      child: _Dlazdice(
                        klic: 'prijem-dezen',
                        nadpis:
                            'DEZÉN PNEU · ${dezen.zimni ? 'ZIMNÍ' : 'LETNÍ'}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SchemaDezenu(dezen: dezen),
                            const SizedBox(height: Insets.sm),
                            StitekDezenu(dezen: dezen),
                          ],
                        ),
                      ),
                    ),
                  if (stk != null)
                    SizedBox(
                      width: sirka,
                      child: _Stk(datum: stk.datum!),
                    ),
                ],
              );
            },
          ),
          if (fotky.isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            Text(
              'FOTKY Z PŘÍJMU  ${fotky.length}',
              style: AppTextStyles.overline.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.sm),
            _Nahledy(fotky: fotky, onTap: widget.onFotky),
          ],
          const SizedBox(height: Insets.sm),
          TextButton.icon(
            key: const Key('prijem-checklist'),
            onPressed: () => setState(() => _checklist = !_checklist),
            icon: Icon(
              _checklist
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
            ),
            label: Text(
              'Celý checklist (${p.pocetVyplnenych}/${p.pocetPovinnych} '
              'zkontrolováno, ${nalezy.length} s poznámkou)',
            ),
          ),
          if (_checklist)
            for (final polozka in p.polozky) _RadekChecklistu(polozka: polozka),
        ],
      ),
    );
  }
}

/// Fotky nafocené během příjmu - od zahájení do dokončení (rozpracovaný
/// do teď), s pár minutami rezervy na obě strany.
List<Fotka> _fotkyZPrijmu(List<Fotka> fotky, Prijem prijem) {
  final od = prijem.zahajenoAt;
  if (od == null) return const [];
  final zacatek = od.subtract(_rezervaFotek);
  final konec = (prijem.dokoncenoAt ?? DateTime.now()).add(_rezervaFotek);
  return [
    for (final f in fotky)
      if (!f.nahranoAt.isBefore(zacatek) && !f.nahranoAt.isAfter(konec)) f,
  ];
}

class _Dlazdice extends StatelessWidget {
  const _Dlazdice({
    required this.klic,
    required this.nadpis,
    required this.child,
    this.barva,
  });

  final String klic;
  final String nadpis;
  final Widget child;
  final Color? barva;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: Key(klic),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: barva ?? palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nadpis,
            style: AppTextStyles.overline.copyWith(
              color: barva ?? palette.muted,
            ),
          ),
          const SizedBox(height: Insets.sm),
          child,
        ],
      ),
    );
  }
}

/// Nálezy - body, u kterých technik něco napsal. Poradce z nich dělá
/// nabídku víceprací.
class _Nalezy extends StatelessWidget {
  const _Nalezy({required this.nalezy});

  final List<PolozkaPrijmu> nalezy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (nalezy.isEmpty) {
      return _Dlazdice(
        klic: 'prijem-nalezy',
        nadpis: 'NÁLEZY',
        barva: AppColors.readyGreen,
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.readyGreen,
              size: 20,
            ),
            const SizedBox(width: Insets.sm),
            Text(
              'Bez nálezů',
              style: AppTextStyles.cardBody.copyWith(
                color: AppColors.readyGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return _Dlazdice(
      klic: 'prijem-nalezy',
      nadpis: 'NÁLEZY  ${nalezy.length}',
      barva: _zluta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, n) in nalezy.indexed) ...[
            if (i > 0) const SizedBox(height: Insets.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: _zluta,
                  size: 18,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.nazev,
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        n.poznamka!.trim(),
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Platnost STK - propadlá červeně, končící do dvou měsíců žlutě.
class _Stk extends StatelessWidget {
  const _Stk({required this.datum});

  final DateTime datum;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dnes = DateUtils.dateOnly(DateTime.now());
    final dni = DateUtils.dateOnly(datum).difference(dnes).inDays;
    final (popis, barva) = dni < 0
        ? ('Propadlá', AppColors.danger)
        : dni <= 61
        ? ('Končí za ${dni == 0 ? 'dnes' : '$dni dní'}', _zluta)
        : ('Za ${(dni / 30.4).round()} měsíců', palette.muted);
    return _Dlazdice(
      klic: 'prijem-stk',
      nadpis: 'STK',
      barva: dni <= 61 ? barva : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'do ${AppDateFormat.date(datum)}',
            style: AppTextStyles.cardBody.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            popis,
            style: AppTextStyles.metaSmall.copyWith(
              color: barva,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Náhledy fotek z příjmu - klepnutí otevře fotodokumentaci.
class _Nahledy extends StatelessWidget {
  const _Nahledy({required this.fotky, this.onTap});

  final List<Fotka> fotky;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const mezera = Insets.sm;
        final mist = ((constraints.maxWidth + mezera) / (72 + mezera))
            .floor()
            .clamp(3, 8);
        final strana = (constraints.maxWidth - mezera * (mist - 1)) / mist;
        final zbyva = fotky.length > mist ? fotky.length - (mist - 1) : 0;
        final viditelne = fotky.take(zbyva > 0 ? mist - 1 : mist).toList();
        return GestureDetector(
          key: const Key('prijem-fotky'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              for (final (i, f) in viditelne.indexed) ...[
                if (i > 0) const SizedBox(width: mezera),
                _Nahled(fotka: f, strana: strana),
              ],
              if (zbyva > 0) ...[
                const SizedBox(width: mezera),
                Container(
                  width: strana,
                  height: strana,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(Radii.input),
                  ),
                  child: Text(
                    '+$zbyva',
                    style: AppTextStyles.cardBody.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Nahled extends ConsumerWidget {
  const _Nahled({required this.fotka, required this.strana});

  final Fotka fotka;
  final double strana;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final obrazek = ref.watch(obrazekFotkyProvider(fotka.id));
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.input),
          child: Container(
            width: strana,
            height: strana,
            color: palette.plate,
            child: obrazek.when(
              data: (bajty) => Image.memory(
                bajty,
                fit: BoxFit.cover,
                cacheWidth: 200,
                gaplessPlayback: true,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) =>
                  Icon(Icons.broken_image_outlined, color: palette.muted),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: strana,
          child: Text(
            fotka.kategorie.nazev,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.metaSmall.copyWith(
              fontSize: 10.5,
              color: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bod checklistu - výsledek a poznámka.
class _RadekChecklistu extends StatelessWidget {
  const _RadekChecklistu({required this.polozka});

  final PolozkaPrijmu polozka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dezen = polozka.dezen;
    final vysledek = switch (polozka.typ) {
      TypKontroly.datum =>
        polozka.datum == null ? 'Nezadáno' : AppDateFormat.date(polozka.datum!),
      TypKontroly.pneu =>
        dezen == null || !dezen.jeKompletni
            ? 'Nezměřeno'
            : '${dezen.popis} · ${dezen.stav!.label}',
      TypKontroly.kontrola => polozka.splneno ? 'V pořádku' : 'Nezkontrolováno',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            polozka.jeVyplnena
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: polozka.jeVyplnena ? AppColors.readyGreen : palette.muted,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  polozka.nazev,
                  style: AppTextStyles.cardBody.copyWith(color: palette.text),
                ),
                Text(
                  vysledek,
                  style: AppTextStyles.metaSmall.copyWith(
                    color: polozka.typ == TypKontroly.pneu && dezen != null
                        ? barvaDezenu(dezen.stav, palette)
                        : palette.muted,
                  ),
                ),
                if ((polozka.poznamka ?? '').trim().isNotEmpty)
                  Text(
                    polozka.poznamka!.trim(),
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.text,
                      fontStyle: FontStyle.italic,
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
