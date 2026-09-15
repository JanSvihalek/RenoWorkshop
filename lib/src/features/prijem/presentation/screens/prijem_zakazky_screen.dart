import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/rozlozeni.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/hlavicka_zakazky.dart';
import '../../../fotodokumentace/presentation/controllers/fotky_providers.dart';
import '../../../fotodokumentace/presentation/screens/fotodokumentace_screen.dart';
import '../../../fotodokumentace/presentation/widgets/fotodokumentace_karta.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../domain/entities/prijem.dart';
import '../controllers/prijem_providers.dart';

/// Kroky příjmu v pořadí, jak se vůz přijímá: ověřit, že je to ten vůz,
/// obejít ho s fotoaparátem, projít technické kontroly a dokončit.
enum KrokPrijmu {
  vozidlo('Vozidlo'),
  fotky('Fotodokumentace'),
  kontrola('Kontrola'),
  souhrn('Souhrn');

  const KrokPrijmu(this.nazev);

  final String nazev;
}

/// Příjem vozidla u zakázky jako průvodce po krocích - stejně jako
/// v Torkisu: nahoře kde technik je, dole zpět a Pokračovat.
///
/// Mezi kroky jde volně přecházet: někdo nejdřív fotí, jiný začne
/// kontrolou. Povinný checklist hlídá až Dokončit v posledním kroku,
/// kde je vidět, co chybí. Každá změna se ukládá hned.
class PrijemZakazkyScreen extends ConsumerStatefulWidget {
  const PrijemZakazkyScreen({
    super.key,
    required this.orderId,
    required this.onBack,
  });

  final String orderId;
  final VoidCallback onBack;

  @override
  ConsumerState<PrijemZakazkyScreen> createState() =>
      _PrijemZakazkyScreenState();
}

class _PrijemZakazkyScreenState extends ConsumerState<PrijemZakazkyScreen> {
  /// `null`, dokud se příjem nenačte - dokončený se otevře na souhrnu.
  KrokPrijmu? _krok;

  String get _orderId => widget.orderId;

  PrijemController get _controller =>
      ref.read(prijemZakazkyProvider(_orderId).notifier);

  void _ukazChybu(String? chyba) {
    if (chyba == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(chyba)));
  }

  void _jdiNa(KrokPrijmu krok) => setState(() => _krok = krok);

  Future<void> _zmen(String kod, ZmenaPolozky zmena) async {
    _ukazChybu(await _controller.zmen(kod, zmena));
  }

  Future<void> _vyberDatum(PolozkaPrijmu polozka) async {
    final dnes = DateTime.now();
    final datum = await showDatePicker(
      context: context,
      initialDate: polozka.datum ?? dnes,
      // Propadlá STK je taky údaj, který je potřeba zapsat.
      firstDate: DateTime(dnes.year - 10),
      lastDate: DateTime(dnes.year + 10),
      helpText: polozka.nazev,
    );
    if (datum == null || !mounted) return;
    await _zmen(polozka.kod, ZmenaPolozky.datum(datum));
  }

  Future<void> _upravPoznamku(PolozkaPrijmu polozka) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _PoznamkaDialog(
        nazev: polozka.nazev,
        poznamka: polozka.poznamka ?? '',
      ),
    );
    if (text == null || text.trim() == (polozka.poznamka ?? '')) return;
    if (!mounted) return;
    await _zmen(polozka.kod, ZmenaPolozky.poznamka(text));
  }

  /// Bez hlášky o úspěchu: souhrn ukáže zelený pruh a snackbar by na
  /// telefonu zakryl tlačítka dole.
  Future<void> _dokonci() async => _ukazChybu(await _controller.dokonci());

  Future<void> _znovuOtevri() async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Znovu otevřít příjem?'),
        content: const Text(
          'Checklist půjde upravit a příjem bude potřeba znovu dokončit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Otevřít'),
          ),
        ],
      ),
    );
    if (!(potvrzeno ?? false) || !mounted) return;
    _ukazChybu(await _controller.znovuOtevri());
  }

  /// Hotové kroky dostanou v bočním seznamu fajfku.
  bool _hotovy(KrokPrijmu krok, Prijem prijem, int pocetFotek) =>
      switch (krok) {
        KrokPrijmu.vozidlo => _krok!.index > 0 || prijem.jeDokoncen,
        KrokPrijmu.fotky => pocetFotek > 0,
        KrokPrijmu.kontrola => prijem.chybi == 0,
        KrokPrijmu.souhrn => prijem.jeDokoncen,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final zakazka = ref.watch(orderByIdProvider(_orderId)).valueOrNull;
    final prijemAsync = ref.watch(prijemZakazkyProvider(_orderId));
    final pocetFotek =
        ref.watch(fotkyZakazkyProvider(_orderId)).valueOrNull?.length ?? 0;

    final prijem = prijemAsync.valueOrNull;
    if (prijem != null && _krok == null) {
      _krok = prijem.jeDokoncen ? KrokPrijmu.souhrn : KrokPrijmu.vozidlo;
    }

    final Widget telo;
    if (prijem != null) {
      telo = _pruvodce(context, zakazka, prijem, pocetFotek);
    } else if (prijemAsync.hasError) {
      telo = _Chyba(
        zprava: '${prijemAsync.error}',
        onZnovu: () => ref.invalidate(prijemZakazkyProvider(_orderId)),
      );
    } else {
      telo = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          HlavickaZakazky(
            nadpis: 'Příjem vozidla',
            onBack: widget.onBack,
            cisloZakazky: _orderId,
            spz: zakazka?.licensePlate,
            model: zakazka?.model,
          ),
          Expanded(child: telo),
        ],
      ),
    );
  }

  Widget _pruvodce(
    BuildContext context,
    ServiceOrder? zakazka,
    Prijem prijem,
    int pocetFotek,
  ) {
    final krok = _krok!;
    final naTabletu = context.jeTablet;
    final obsah = Column(
      children: [
        if (!naTabletu)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.base,
              Insets.xl,
              0,
            ),
            child: _PostupKroku(krok: krok),
          ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(krok),
            child: _obsahKroku(krok, zakazka, prijem),
          ),
        ),
        _SpodniPanel(
          krok: krok,
          prijem: prijem,
          naTabletu: naTabletu,
          onZpet: () => _jdiNa(KrokPrijmu.values[krok.index - 1]),
          onPokracovat: () => _jdiNa(KrokPrijmu.values[krok.index + 1]),
          onDokoncit: _dokonci,
          onHotovo: widget.onBack,
        ),
      ],
    );

    if (!naTabletu) return obsah;

    // Na tabletu jsou kroky vlevo jako v Torkisu - je vidět celý postup
    // a na krok jde klepnout.
    return Row(
      children: [
        _BocniKroky(
          aktivni: krok,
          prijem: prijem,
          hotovy: (k) => _hotovy(k, prijem, pocetFotek),
          onVyber: _jdiNa,
        ),
        Container(width: 1, color: context.palette.hairline),
        Expanded(child: obsah),
      ],
    );
  }

  Widget _obsahKroku(KrokPrijmu krok, ServiceOrder? zakazka, Prijem prijem) {
    const odsazeni = EdgeInsets.fromLTRB(
      Insets.xl,
      Insets.lg,
      Insets.xl,
      Insets.xl,
    );
    return switch (krok) {
      KrokPrijmu.vozidlo => ListView(
        padding: odsazeni,
        children: [_KrokVozidlo(zakazka: zakazka)],
      ),
      KrokPrijmu.fotky => FotodokumentaceObsah(orderId: _orderId),
      KrokPrijmu.kontrola => ListView(
        padding: odsazeni,
        children: [
          _Checklist(
            prijem: prijem,
            onZaskrtnout: (polozka, hodnota) =>
                _zmen(polozka.kod, ZmenaPolozky.splneno(hodnota)),
            onDatum: _vyberDatum,
            onPoznamka: _upravPoznamku,
          ),
        ],
      ),
      KrokPrijmu.souhrn => ListView(
        padding: odsazeni,
        children: [
          if (prijem.jeDokoncen) ...[
            _Dokonceno(prijem: prijem, onZnovuOtevrit: _znovuOtevri),
            const SizedBox(height: Insets.base),
          ],
          _SouhrnKontroly(
            prijem: prijem,
            onUpravit: () => _jdiNa(KrokPrijmu.kontrola),
          ),
          const SizedBox(height: Insets.base),
          FotodokumentaceKarta(
            orderId: _orderId,
            onOtevrit: () => _jdiNa(KrokPrijmu.fotky),
          ),
        ],
      ),
    };
  }
}

/// „KROK 2 Z 4 · FOTODOKUMENTACE" a ukazatel postupu - na telefonu.
class _PostupKroku extends StatelessWidget {
  const _PostupKroku({required this.krok});

  final KrokPrijmu krok;

  @override
  Widget build(BuildContext context) {
    final celkem = KrokPrijmu.values.length;
    return Row(
      children: [
        Text(
          'KROK ${krok.index + 1} Z $celkem · ${krok.nazev.toUpperCase()}',
          key: const Key('prijem-krok'),
          style: AppTextStyles.overline.copyWith(color: AppColors.accent),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (krok.index + 1) / celkem,
              minHeight: 4,
              backgroundColor: context.palette.hairline,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// Seznam kroků vlevo na tabletu.
class _BocniKroky extends StatelessWidget {
  const _BocniKroky({
    required this.aktivni,
    required this.prijem,
    required this.hotovy,
    required this.onVyber,
  });

  final KrokPrijmu aktivni;
  final Prijem prijem;
  final bool Function(KrokPrijmu krok) hotovy;
  final ValueChanged<KrokPrijmu> onVyber;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 240,
      color: palette.card,
      padding: const EdgeInsets.all(Insets.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final krok in KrokPrijmu.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Material(
                color: krok == aktivni
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.input),
                child: InkWell(
                  key: Key('prijem-krok-${krok.name}'),
                  borderRadius: BorderRadius.circular(Radii.input),
                  onTap: () => onVyber(krok),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Row(
                      children: [
                        _Odznak(
                          poradi: krok.index + 1,
                          aktivni: krok == aktivni,
                          hotovy: hotovy(krok),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Text(
                            krok.nazev,
                            style: AppTextStyles.cardBody.copyWith(
                              color: palette.text,
                              fontWeight: krok == aktivni
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Text(
            'Zkontrolováno ${prijem.pocetVyplnenych} z ${prijem.pocetPovinnych}',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prijem.pocetPovinnych == 0
                  ? 0
                  : prijem.pocetVyplnenych / prijem.pocetPovinnych,
              minHeight: 4,
              backgroundColor: palette.hairline,
              valueColor: const AlwaysStoppedAnimation(AppColors.readyGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _Odznak extends StatelessWidget {
  const _Odznak({
    required this.poradi,
    required this.aktivni,
    required this.hotovy,
  });

  final int poradi;
  final bool aktivni;
  final bool hotovy;

  @override
  Widget build(BuildContext context) {
    final barva = hotovy
        ? AppColors.readyGreen
        : (aktivni ? AppColors.accent : context.palette.hairline2);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: barva, shape: BoxShape.circle),
      child: hotovy
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Text(
              '$poradi',
              style: AppTextStyles.chip.copyWith(
                color: aktivni ? Colors.white : context.palette.muted,
              ),
            ),
    );
  }
}

/// Zpět a Pokračovat, v posledním kroku Dokončit příjem.
class _SpodniPanel extends StatelessWidget {
  const _SpodniPanel({
    required this.krok,
    required this.prijem,
    required this.naTabletu,
    required this.onZpet,
    required this.onPokracovat,
    required this.onDokoncit,
    required this.onHotovo,
  });

  final KrokPrijmu krok;
  final Prijem prijem;
  final bool naTabletu;
  final VoidCallback onZpet;
  final VoidCallback onPokracovat;
  final VoidCallback onDokoncit;
  final VoidCallback onHotovo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final posledni = krok == KrokPrijmu.values.last;

    final Widget hlavni;
    if (!posledni) {
      hlavni = FilledButton(
        key: const Key('prijem-pokracovat'),
        onPressed: onPokracovat,
        child: const Text('Pokračovat'),
      );
    } else if (prijem.jeDokoncen) {
      hlavni = FilledButton(
        key: const Key('prijem-hotovo'),
        onPressed: onHotovo,
        child: const Text('Hotovo'),
      );
    } else {
      hlavni = FilledButton(
        key: const Key('dokoncit-prijem'),
        onPressed: prijem.chybi == 0 ? onDokoncit : null,
        child: Text(
          prijem.chybi == 0
              ? 'Dokončit příjem'
              : 'Zbývá zkontrolovat: ${prijem.chybi}',
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.md,
        Insets.xl,
        Insets.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          if (krok.index > 0) ...[
            SizedBox(
              width: Sizes.ctaHeight,
              height: Sizes.ctaHeight,
              child: Tooltip(
                message: 'Předchozí krok',
                child: OutlinedButton(
                  key: const Key('prijem-zpet'),
                  onPressed: onZpet,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: palette.hairline2),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: palette.text),
                ),
              ),
            ),
            const SizedBox(width: Insets.md),
          ],
          if (naTabletu) ...[
            const Spacer(),
            SizedBox(width: 280, height: Sizes.ctaHeight, child: hlavni),
          ] else
            Expanded(
              child: SizedBox(height: Sizes.ctaHeight, child: hlavni),
            ),
        ],
      ),
    );
  }
}

/// Krok 1: ověřit, že technik stojí u správného vozu.
class _KrokVozidlo extends StatelessWidget {
  const _KrokVozidlo({required this.zakazka});

  final ServiceOrder? zakazka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final z = zakazka;
    if (z == null) {
      return const Padding(
        padding: EdgeInsets.all(Insets.huge),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('VOZIDLO'),
              const SizedBox(height: Insets.sm),
              Text(
                z.licensePlate,
                style: AppTextStyles.plateLarge.copyWith(color: palette.text),
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                z.model,
                style: AppTextStyles.cardModel.copyWith(color: palette.text),
              ),
              const SizedBox(height: Insets.base),
              Text(
                'VIN',
                style: AppTextStyles.overline.copyWith(color: palette.muted),
              ),
              SelectableText(
                z.vin,
                style: AppTextStyles.monoLabel.copyWith(
                  fontSize: 17,
                  color: palette.text,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: Insets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'Porovnejte SPZ a VIN na voze se zakázkou, než začnete '
                      'fotit a kontrolovat.',
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.base),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('ZAKÁZKA'),
              const SizedBox(height: Insets.sm),
              _Radek('Zákazník', z.customerName),
              if (z.typZakazky != null) _Radek('Typ', z.typZakazky!.nazev),
              if (z.pojisteniPopisek != null)
                _Radek('Pojištění', z.pojisteniPopisek!),
              if (z.mechanicName != null)
                _Radek(ServiceOrder.rolePopisek, z.mechanicName!),
              if ((z.predmetOpravy ?? '').isNotEmpty)
                _Radek('Předmět opravy', z.predmetOpravy!),
            ],
          ),
        ),
      ],
    );
  }
}

class _Radek extends StatelessWidget {
  const _Radek(this.popisek, this.hodnota);

  final String popisek;
  final String hodnota;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              popisek,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          ),
          Expanded(
            child: Text(
              hodnota,
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Krok 3: checklist kontrol.
class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.prijem,
    required this.onZaskrtnout,
    required this.onDatum,
    required this.onPoznamka,
  });

  final Prijem prijem;
  final void Function(PolozkaPrijmu polozka, bool hodnota) onZaskrtnout;
  final ValueChanged<PolozkaPrijmu> onDatum;
  final ValueChanged<PolozkaPrijmu> onPoznamka;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.xl,
        Insets.base,
        Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('KONTROLA PŘI PŘÍJMU')),
              Text(
                '${prijem.pocetVyplnenych} / ${prijem.pocetPovinnych}',
                key: const Key('prijem-postup'),
                style: AppTextStyles.chip.copyWith(
                  color: prijem.chybi == 0
                      ? AppColors.readyGreen
                      : context.palette.muted,
                ),
              ),
              const SizedBox(width: Insets.sm),
            ],
          ),
          const SizedBox(height: Insets.sm),
          for (final polozka in prijem.polozky)
            _Polozka(
              key: Key('kontrola-${polozka.kod}'),
              polozka: polozka,
              zamceno: prijem.jeDokoncen,
              onZaskrtnout: (hodnota) => onZaskrtnout(polozka, hodnota),
              onDatum: () => onDatum(polozka),
              onPoznamka: () => onPoznamka(polozka),
            ),
        ],
      ),
    );
  }
}

/// Krok 4: co je zkontrolované, co chybí a jaké jsou nálezy.
class _SouhrnKontroly extends StatelessWidget {
  const _SouhrnKontroly({required this.prijem, required this.onUpravit});

  final Prijem prijem;
  final VoidCallback onUpravit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chybejici = [
      for (final p in prijem.polozky)
        if (p.povinna && !p.jeVyplnena) p,
    ];
    final nalezy = [
      for (final p in prijem.polozky)
        if ((p.poznamka ?? '').isNotEmpty) p,
    ];
    final stk = prijem.polozky
        .where((p) => p.typ == TypKontroly.datum && p.datum != null)
        .firstOrNull;

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('KONTROLA')),
              if (!prijem.jeDokoncen)
                TextButton(onPressed: onUpravit, child: const Text('Upravit')),
            ],
          ),
          Row(
            children: [
              Icon(
                chybejici.isEmpty
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: chybejici.isEmpty
                    ? AppColors.readyGreen
                    : AppColors.danger,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  chybejici.isEmpty
                      ? 'Zkontrolováno vše (${prijem.pocetPovinnych})'
                      : 'Chybí zkontrolovat: ${chybejici.length}',
                  key: const Key('prijem-souhrn-stav'),
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          for (final p in chybejici)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: Insets.xs),
              child: Text(
                '• ${p.nazev}',
                style: AppTextStyles.metaSmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ),
          if (stk != null) ...[
            const SizedBox(height: Insets.md),
            _Radek(stk.nazev, AppDateFormat.date(stk.datum!)),
          ],
          if (nalezy.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            Text(
              'NÁLEZY',
              style: AppTextStyles.overline.copyWith(color: palette.muted),
            ),
            for (final p in nalezy)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nazev,
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      p.poznamka!,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Polozka extends StatelessWidget {
  const _Polozka({
    super.key,
    required this.polozka,
    required this.zamceno,
    required this.onZaskrtnout,
    required this.onDatum,
    required this.onPoznamka,
  });

  final PolozkaPrijmu polozka;
  final bool zamceno;
  final ValueChanged<bool> onZaskrtnout;
  final VoidCallback onDatum;
  final VoidCallback onPoznamka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final jeDatum = polozka.typ == TypKontroly.datum;
    final poznamka = polozka.poznamka;

    return InkWell(
      // U kontroly přepne zaškrtnutí celý řádek - v rukavicích se do
      // malého čtverečku netrefí nikdo.
      onTap: zamceno
          ? null
          : (jeDatum ? onDatum : () => onZaskrtnout(!polozka.splneno)),
      borderRadius: BorderRadius.circular(Radii.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: jeDatum
                  ? Icon(
                      polozka.jeVyplnena
                          ? Icons.event_available_rounded
                          : Icons.event_rounded,
                      color: polozka.jeVyplnena
                          ? AppColors.readyGreen
                          : palette.muted,
                    )
                  : Checkbox(
                      value: polozka.splneno,
                      onChanged: zamceno
                          ? null
                          : (hodnota) => onZaskrtnout(hodnota ?? false),
                    ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      polozka.nazev,
                      style: AppTextStyles.cardBody.copyWith(
                        color: polozka.povinna ? palette.text : palette.muted,
                      ),
                    ),
                    if (jeDatum) ...[
                      const SizedBox(height: 2),
                      Text(
                        polozka.datum == null
                            ? 'Klepněte a zadejte datum'
                            : AppDateFormat.date(polozka.datum!),
                        style: AppTextStyles.cardBody.copyWith(
                          color: polozka.datum == null
                              ? AppColors.accent
                              : palette.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (poznamka != null && poznamka.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        poznamka,
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Poznámka',
              onPressed: zamceno ? null : onPoznamka,
              icon: Icon(
                (poznamka ?? '').isEmpty
                    ? Icons.edit_note_rounded
                    : Icons.sticky_note_2_rounded,
                color: (poznamka ?? '').isEmpty
                    ? palette.muted
                    : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dokonceno extends StatelessWidget {
  const _Dokonceno({required this.prijem, required this.onZnovuOtevrit});

  final Prijem prijem;
  final VoidCallback onZnovuOtevrit;

  @override
  Widget build(BuildContext context) {
    final kdy = prijem.dokoncenoAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.base,
        Insets.base,
        Insets.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.readyGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.readyGreen.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, color: AppColors.readyGreen),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              [
                'Příjem dokončen',
                if (kdy != null) AppDateFormat.dateTime(kdy),
                if (prijem.dokoncilKdo != null) prijem.dokoncilKdo!,
              ].join(' · '),
              style: AppTextStyles.cardBody.copyWith(
                color: context.palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onZnovuOtevrit,
            child: const Text('Znovu otevřít'),
          ),
        ],
      ),
    );
  }
}

class _PoznamkaDialog extends StatefulWidget {
  const _PoznamkaDialog({required this.nazev, required this.poznamka});

  final String nazev;
  final String poznamka;

  @override
  State<_PoznamkaDialog> createState() => _PoznamkaDialogState();
}

class _PoznamkaDialogState extends State<_PoznamkaDialog> {
  late final TextEditingController _pole = TextEditingController(
    text: widget.poznamka,
  );

  @override
  void dispose() {
    _pole.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.nazev),
      content: TextField(
        controller: _pole,
        autofocus: true,
        maxLength: 500,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Co jste při kontrole našli',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_pole.text),
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}

class _Chyba extends StatelessWidget {
  const _Chyba({required this.zprava, required this.onZnovu});

  final String zprava;
  final VoidCallback onZnovu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 34, color: palette.muted),
            const SizedBox(height: Insets.base),
            Text(
              zprava,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.text),
            ),
            const SizedBox(height: Insets.xl),
            FilledButton(onPressed: onZnovu, child: const Text('Zkusit znovu')),
          ],
        ),
      ),
    );
  }
}
