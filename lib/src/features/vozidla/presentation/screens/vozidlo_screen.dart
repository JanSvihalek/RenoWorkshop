import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigace/pozadavek_skeneru.dart';
import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/workshop_bottom_nav.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../../orders/presentation/widgets/order_search_field.dart';
import '../../../orders/presentation/widgets/plate_chip.dart';
import '../../../prijem/presentation/widgets/identifikace_karta.dart';
import '../../domain/entities/vozidlo.dart';
import '../controllers/vozidla_providers.dart';

/// SPZ tak, jak se porovnává: velká písmena, bez mezer a pomlček.
String kodSpz(String spz) => spz.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Vypadá dotaz jako číslo zakázky? `Z1212…` nebo aspoň šest číslic -
/// kratší čísla by se míchala s číslicemi ze SPZ.
bool _jakoCisloZakazky(String kod) =>
    (kod.startsWith('Z') && kod.length >= 4) ||
    RegExp(r'^\d{6,}$').hasMatch(kod);

/// Rozdělané zakázky, kterým dotaz sedí na SPZ, VIN nebo číslo zakázky.
/// Nejnovější příjem první.
List<ServiceOrder> zakazkyPodleDotazu(
  List<ServiceOrder> zakazky,
  String dotaz,
) {
  final hledane = kodSpz(dotaz);
  if (hledane.length < 3) return const [];
  final cislo = _jakoCisloZakazky(hledane);
  return [
    for (final zakazka in zakazky)
      if (kodSpz(zakazka.licensePlate).contains(hledane) ||
          kodSpz(zakazka.vin).contains(hledane) ||
          (cislo && kodSpz(zakazka.id).contains(hledane)))
        zakazka,
  ]..sort(
    (a, b) =>
        (b.receivedAt ?? DateTime(0)).compareTo(a.receivedAt ?? DateTime(0)),
  );
}

/// „Nalezeny 2 otevřené zakázky", „Nalezeno 5 otevřených zakázek".
String pocetOtevrenychZakazek(int pocet) => switch (pocet) {
  1 => 'Nalezena 1 otevřená zakázka',
  >= 2 && <= 4 => 'Nalezeny $pocet otevřené zakázky',
  _ => 'Nalezeno $pocet otevřených zakázek',
};

/// Záložka Vozidlo - dřív zvlášť Příjem a Vozidla, obě začínaly SPZ.
///
/// Hledá se podle SPZ, VINu i čísla zakázky, obojí naráz:
///   * mezi zakázkami na dílně - vůz s rozdělanou zakázkou ukáže kartu
///     k potvrzení s dlaždicí „Zahájit příjem" (krok 1 příjmu),
///   * v evidenci vozidel z Heliosu - karta vozu s majitelem a všemi
///     zakázkami.
///
/// Vůz bez zakázky na dílně je hned seznam vozů; jediný naskenovaný se
/// otevře rovnou přes celou obrazovku. Tlačítko příjmu vidí i mechanici,
/// kteří příjem nedělají - Jan to tak chce zkusit (5. 10. 2026).
class VozidloScreen extends ConsumerStatefulWidget {
  const VozidloScreen({
    super.key,
    required this.onOpenZakazka,
    required this.onOpenDetail,
    required this.onOpenVozidlo,
    required this.onScan,
  });

  /// Zahájit (pokračovat v) příjmu zakázky.
  final void Function(ServiceOrder zakazka) onOpenZakazka;

  /// Detail nalezené zakázky - postup, pracovní list, fotky.
  final void Function(ServiceOrder zakazka) onOpenDetail;

  /// `naskenovano` - hledání vyplnil skener, ne klávesnice. Karta vozu to
  /// ukáže v popisku.
  final void Function(NalezeneVozidlo vozidlo, bool naskenovano) onOpenVozidlo;
  final VoidCallback onScan;

  @override
  ConsumerState<VozidloScreen> createState() => _VozidloScreenState();
}

class _VozidloScreenState extends ConsumerState<VozidloScreen> {
  final TextEditingController _pole = TextEditingController();
  final FocusNode _fokus = FocusNode();
  Timer? _debounce;
  bool _synchronizuje = false;

  /// Poslední dotaz, který do providera poslalo samo pole. Podle něj se
  /// pozná změna zvenčí (skener) od vlastního psaní - to se do pole
  /// vracet nesmí, jinak by přepsalo znaky napsané během zpoždění.
  String _odeslany = '';

  /// Poslední dotaz vyplnil skener - platí, dokud člověk nezačne psát.
  bool _zeSkeneru = false;

  @override
  void initState() {
    super.initState();
    // Záložka se staví až při prvním otevření - požadavek už čeká.
    _vyzvedniPozadavek(ref.read(pozadavekSkeneruProvider));
    _pole.text = ref.read(dotazVozidlaProvider);
    _odeslany = _pole.text;
    _zeSkeneru = ref.read(otevritJedineVozidloProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pole.dispose();
    _fokus.dispose();
    super.dispose();
  }

  void _psani(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // Psaní rukou nikdy neotvírá kartu samo - viz otevritJedineVozidlo.
      ref.read(otevritJedineVozidloProvider.notifier).state = false;
      _zeSkeneru = false;
      _odeslany = text;
      ref.read(dotazVozidlaProvider.notifier).state = text;
    });
    setState(() {});
  }

  /// Dotáhne zakázky z Heliosu hned, bez čekání na pětiminutový běh.
  Future<void> _synchronizuj() async {
    setState(() => _synchronizuje = true);
    try {
      await ref.read(serviceOrderDataSourceProvider).synchronizuj();
      ref.invalidate(ordersStreamProvider);
      await ref.read(ordersStreamProvider.future);
    } on ServiceOrderException catch (chyba) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(chyba.message)));
      }
    } finally {
      if (mounted) setState(() => _synchronizuje = false);
    }
  }

  /// Nalezené to není - hledání pryč a znovu skener.
  void _neniToOno() {
    _debounce?.cancel();
    _pole.clear();
    _odeslany = '';
    _zeSkeneru = false;
    ref.read(otevritJedineVozidloProvider.notifier).state = false;
    ref.read(dotazVozidlaProvider.notifier).state = '';
    setState(() {});
    widget.onScan();
  }

  /// Skener po klepnutí na záložku - vůz se vždycky hledá podle SPZ.
  /// Požadavek vystaví navigace; tady se vyzvedne a hned zahodí, takže po
  /// návratu ze skeneru ani po přepnutí zpět se znovu neotevře. Když je
  /// v hledání něco rozdělaného, skener se nespouští.
  void _vyzvedniPozadavek(WorkshopTab? pozadavek) {
    if (pozadavek != WorkshopTab.vozidlo) return;
    // Mimo sestavování - stav providera se během něj měnit nesmí.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(pozadavekSkeneruProvider) != WorkshopTab.vozidlo) return;
      ref.read(pozadavekSkeneruProvider.notifier).state = null;
      if (ref.read(dotazVozidlaProvider).trim().isNotEmpty) return;
      widget.onScan();
    });
  }

  /// Po naskenování: vůz bez zakázky na dílně a jediný v evidenci se
  /// otevře rovnou. S rozdělanou zakázkou se nikam nejde - karta příjmu
  /// je přímo tady.
  void _otevriJedine(
    List<ServiceOrder>? nalezene,
    List<NalezeneVozidlo>? vozidla,
  ) {
    if (!ref.read(otevritJedineVozidloProvider)) return;
    if (nalezene == null) return;
    if (nalezene.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(otevritJedineVozidloProvider.notifier).state = false;
        }
      });
      return;
    }
    if (vozidla == null) return;
    // Navigace nesmí proběhnout uprostřed sestavování obrazovky.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(otevritJedineVozidloProvider)) return;
      ref.read(otevritJedineVozidloProvider.notifier).state = false;
      if (vozidla.length == 1) widget.onOpenVozidlo(vozidla.single, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dotaz = ref.watch(dotazVozidlaProvider).trim();
    ref.listen(pozadavekSkeneruProvider, (_, novy) => _vyzvedniPozadavek(novy));
    // Ze skeneru přes „Zadat ručně" - kurzor do pole, ať jde hned psát.
    ref.listen(zadatRucneProvider, (_, novy) {
      if (novy != WorkshopTab.vozidlo) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(zadatRucneProvider.notifier).state = null;
        _fokus.requestFocus();
      });
    });
    // Skener dotaz vyplní zvenčí - pole se musí srovnat.
    ref.listen(dotazVozidlaProvider, (_, novy) {
      if (novy == _odeslany) return;
      _odeslany = novy;
      _zeSkeneru = novy.trim().isNotEmpty;
      _debounce?.cancel();
      _pole.text = novy;
      setState(() {});
    });

    final hledat = kodSpz(dotaz).length >= nejkratsiDotazVozidla;
    final zakazky = ref.watch(ordersStreamProvider);
    final nalezene = zakazky.hasValue
        ? zakazkyPodleDotazu(zakazky.value!, dotaz)
        : null;
    final vozidla = hledat ? ref.watch(hledaniVozidelProvider(dotaz)) : null;
    if (hledat) _otevriJedine(nalezene, vozidla?.valueOrNull);

    final Widget obsah;
    if (!hledat) {
      obsah = const _Sdeleni(
        ikona: Icons.directions_car_outlined,
        titulek: 'Najděte vozidlo',
        text:
            'Naskenujte SPZ, nebo napište SPZ, VIN či číslo zakázky. '
            'U vozu na dílně rovnou zahájíte příjem, u každého uvidíte '
            'majitele a všechny zakázky.',
      );
    } else if (zakazky.hasError && !zakazky.hasValue) {
      obsah = _Sdeleni(
        ikona: Icons.cloud_off_rounded,
        titulek: 'Zakázky se nepodařilo načíst',
        text: '${zakazky.error}',
      );
    } else if (nalezene == null) {
      obsah = const Center(child: CircularProgressIndicator());
    } else if (nalezene.isNotEmpty) {
      obsah = _NaDilne(
        nalezene: nalezene,
        naskenovano: _zeSkeneru,
        onZahajit: widget.onOpenZakazka,
        onDetail: widget.onOpenDetail,
        onNeniToOno: _neniToOno,
        vozidla: vozidla!,
        onOpenVozidlo: (v) => widget.onOpenVozidlo(v, _zeSkeneru),
      );
    } else {
      obsah = vozidla!.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (chyba, _) => _Sdeleni(
          ikona: Icons.cloud_off_rounded,
          titulek: 'Hledání se nezdařilo',
          text: '$chyba',
        ),
        data: (seznam) => seznam.isEmpty
            ? _Sdeleni(
                ikona: Icons.search_off_rounded,
                titulek: 'Nic nenalezeno',
                text:
                    'Zkontrolujte SPZ nebo zkuste VIN - SPZ se při '
                    'přeregistraci mění. Pokud poradce zakázku v Heliosu '
                    'založil před chvílí, načtěte nové zakázky.',
                akce: _TlacitkoSynchronizace(
                  synchronizuje: _synchronizuje,
                  onSynchronizuj: _synchronizuj,
                ),
              )
            : _JenVozidla(
                vozidla: seznam,
                synchronizuje: _synchronizuje,
                onSynchronizuj: _synchronizuj,
                onOpenVozidlo: (v) => widget.onOpenVozidlo(v, _zeSkeneru),
              ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          Container(
            decoration: dekoraceHlavicky(palette),
            padding: EdgeInsets.fromLTRB(
              Insets.xxl,
              MediaQuery.paddingOf(context).top + Insets.base,
              Insets.xxl,
              Insets.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vozidlo',
                  style: AppTextStyles.appBarTitle(
                    isIOS: context.isIOS,
                  ).copyWith(color: palette.naHlavicce),
                ),
                const SizedBox(height: Insets.lg),
                OrderSearchField(
                  focusNode: _fokus,
                  controller: _pole,
                  onChanged: _psani,
                  onScan: widget.onScan,
                  hintText: 'SPZ, VIN nebo číslo zakázky',
                  naTmavem: context.isDarkMode,
                ),
              ],
            ),
          ),
          Expanded(child: obsah),
        ],
      ),
    );
  }
}

/// Vůz má zakázku na dílně: karta k potvrzení se „Zahájit příjem" (jedna
/// uprostřed, víc pod sebou k výběru) a pod ní vůz z evidence - majitel
/// a historie jsou o klepnutí dál.
class _NaDilne extends StatelessWidget {
  const _NaDilne({
    required this.nalezene,
    required this.naskenovano,
    required this.onZahajit,
    required this.onDetail,
    required this.onNeniToOno,
    required this.vozidla,
    required this.onOpenVozidlo,
  });

  final List<ServiceOrder> nalezene;
  final bool naskenovano;
  final void Function(ServiceOrder zakazka) onZahajit;
  final void Function(ServiceOrder zakazka) onDetail;
  final VoidCallback onNeniToOno;
  final AsyncValue<List<NalezeneVozidlo>> vozidla;
  final void Function(NalezeneVozidlo vozidlo) onOpenVozidlo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final jedna = nalezene.length == 1;
    final seznamVozidel = vozidla.valueOrNull ?? const <NalezeneVozidlo>[];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.xl,
          Insets.xl,
          Insets.giant,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!jedna) ...[
              // Stejná SPZ u víc otevřených zakázek - po přeregistraci
              // nebo dvě zakázky na jeden vůz.
              Text(
                key: const Key('vice-zakazek'),
                '${pocetOtevrenychZakazek(nalezene.length)} - vyberte tu '
                'správnou',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardBody.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.xl),
            ],
            for (final (i, zakazka) in nalezene.indexed) ...[
              if (i > 0) const SizedBox(height: Insets.huge),
              IdentifikaceKarta(
                zakazka: zakazka,
                naskenovano: naskenovano,
                onZahajit: () => onZahajit(zakazka),
                onDetail: () => onDetail(zakazka),
                onNeniToOno: jedna ? onNeniToOno : null,
              ),
            ],
            // U víc karet „Není to ono" u každé nedává smysl - jedna
            // cesta zpět pro všechny.
            if (!jedna) ...[
              const SizedBox(height: Insets.xl),
              TextButton.icon(
                key: const Key('nic-z-toho'),
                onPressed: onNeniToOno,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Žádná z nich - skenovat znovu'),
              ),
            ],
            if (seznamVozidel.isNotEmpty) ...[
              const SizedBox(height: Insets.huge),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: IdentifikaceKarta.sirkaKarty,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('MAJITEL A HISTORIE VOZU'),
                    const SizedBox(height: Insets.sm),
                    for (final vozidlo in seznamVozidel) ...[
                      RadekVozidla(
                        vozidlo: vozidlo,
                        onTap: () => onOpenVozidlo(vozidlo),
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vůz bez zakázky na dílně: jen vozy z evidence. Nahoře nabídka načíst
/// nové zakázky - poradce mohl zakázku k příjmu založit před chvílí.
class _JenVozidla extends StatelessWidget {
  const _JenVozidla({
    required this.vozidla,
    required this.synchronizuje,
    required this.onSynchronizuj,
    required this.onOpenVozidlo,
  });

  final List<NalezeneVozidlo> vozidla;
  final bool synchronizuje;
  final VoidCallback onSynchronizuj;
  final void Function(NalezeneVozidlo vozidlo) onOpenVozidlo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sirka = MediaQuery.sizeOf(context).width;
    final odsazeni = sirka > 700 ? (sirka - 620) / 2 : Insets.xl;

    return ListView(
      // Na tabletu uprostřed, ne přes celou šířku.
      padding: EdgeInsets.fromLTRB(odsazeni, Insets.lg, odsazeni, Insets.giant),
      children: [
        DetailCard(
          key: const Key('bez-zakazky-na-dilne'),
          padding: const EdgeInsets.all(Insets.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Vůz nemá zakázku na dílně. Pokud ji poradce v Heliosu '
                  'založil před chvílí, načtěte nové zakázky.',
                  style: AppTextStyles.cardBody.copyWith(color: palette.muted),
                ),
              ),
              const SizedBox(width: Insets.md),
              IconButton.filledTonal(
                key: const Key('nacist-nove-zakazky'),
                tooltip: 'Načíst nové zakázky z Heliosu',
                onPressed: synchronizuje ? null : onSynchronizuj,
                icon: synchronizuje
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        for (final vozidlo in vozidla) ...[
          RadekVozidla(vozidlo: vozidlo, onTap: () => onOpenVozidlo(vozidlo)),
          const SizedBox(height: Insets.md),
        ],
      ],
    );
  }
}

class _TlacitkoSynchronizace extends StatelessWidget {
  const _TlacitkoSynchronizace({
    required this.synchronizuje,
    required this.onSynchronizuj,
  });

  final bool synchronizuje;
  final VoidCallback onSynchronizuj;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('nacist-nove-zakazky'),
      onPressed: synchronizuje ? null : onSynchronizuj,
      icon: synchronizuje
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded),
      label: const Text('Načíst nové zakázky z Heliosu'),
    );
  }
}

/// Vůz z evidence v seznamu - klepnutím karta vozu přes celou obrazovku.
class RadekVozidla extends StatelessWidget {
  const RadekVozidla({super.key, required this.vozidlo, required this.onTap});

  final NalezeneVozidlo vozidlo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Vozidlo ${vozidlo.spz}',
      child: GestureDetector(
        key: Key('vozidlo-${vozidlo.id}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vozidlo.spz.isNotEmpty)
                      PlateChip(licensePlate: vozidlo.spz),
                    const SizedBox(height: Insets.sm),
                    Text(
                      vozidlo.model.isEmpty ? 'Neznámý model' : vozidlo.model,
                      style: AppTextStyles.cardModel.copyWith(
                        color: palette.text,
                      ),
                    ),
                    if (vozidlo.majitel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        vozidlo.majitel!,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                    if (vozidlo.vin.isNotEmpty) ...[
                      const SizedBox(height: Insets.xxs),
                      Text(
                        vozidlo.vin,
                        style: AppTextStyles.monoLabel.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Insets.base),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _zakazek(vozidlo.pocetZakazek),
                    style: AppTextStyles.metaSmall.copyWith(
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Icon(Icons.chevron_right_rounded, color: palette.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _zakazek(int pocet) => switch (pocet) {
    0 => 'bez zakázek',
    1 => '1 zakázka',
    >= 2 && <= 4 => '$pocet zakázky',
    _ => '$pocet zakázek',
  };
}

class _Sdeleni extends StatelessWidget {
  const _Sdeleni({
    required this.ikona,
    required this.titulek,
    required this.text,
    this.akce,
  });

  final IconData ikona;
  final String titulek;
  final String text;
  final Widget? akce;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikona, size: 44, color: palette.muted),
            const SizedBox(height: Insets.lg),
            Text(
              titulek,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
            if (akce != null) ...[const SizedBox(height: Insets.xl), akce!],
          ],
        ),
      ),
    );
  }
}
