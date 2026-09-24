import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/presentation/widgets/order_search_field.dart';
import '../../domain/entities/vozidlo.dart';
import '../controllers/vozidla_providers.dart';
import '../widgets/identifikace_vozidla_karta.dart';
import '../../../../core/navigace/pozadavek_skeneru.dart';
import '../../../../core/widgets/workshop_bottom_nav.dart';

/// Vyhledání vozidla podle SPZ nebo VIN.
///
/// Typicky se SPZ naskenuje. Nalezený vůz se ukáže jako karta se všemi
/// údaji - technik ověří, že je to on, a odtud otevře jeho zakázky.
/// Hledá se v celé evidenci vozidel z Heliosu, ne jen mezi auty na dílně.
class VyhledavaniScreen extends ConsumerStatefulWidget {
  const VyhledavaniScreen({
    super.key,
    required this.onOpenVozidlo,
    required this.onScan,
    this.vybraneId,
  });

  final void Function(NalezeneVozidlo vozidlo) onOpenVozidlo;
  final VoidCallback onScan;

  /// Na tabletu je karta vozidla vedle - vybraný řádek musí být poznat.
  final int? vybraneId;

  @override
  ConsumerState<VyhledavaniScreen> createState() => _VyhledavaniScreenState();
}

class _VyhledavaniScreenState extends ConsumerState<VyhledavaniScreen> {
  final TextEditingController _pole = TextEditingController();
  final FocusNode _fokus = FocusNode();
  Timer? _debounce;

  /// Poslední dotaz, který do providera poslalo samo pole. Podle něj se
  /// pozná změna zvenčí (skener) od vlastního psaní - to se do pole
  /// vracet nesmí, jinak by přepsalo znaky napsané během zpoždění.
  String _odeslanyDotaz = '';

  @override
  void initState() {
    super.initState();
    // Záložka se staví až při prvním otevření - požadavek už čeká.
    _vyzvedniPozadavek(ref.read(pozadavekSkeneruProvider));
    _pole.text = ref.read(dotazVozidlaProvider);
    _odeslanyDotaz = _pole.text;
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
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      // Psaní rukou - popisek karty už nemá říkat „naskenováno".
      ref.read(otevritJedineVozidloProvider.notifier).state = false;
      _odeslanyDotaz = text;
      ref.read(dotazVozidlaProvider.notifier).state = text;
    });
    setState(() {});
  }

  /// Nalezený vůz to není - hledání pryč a znovu skener.
  void _neniToOno() {
    _debounce?.cancel();
    _pole.clear();
    _odeslanyDotaz = '';
    ref.read(otevritJedineVozidloProvider.notifier).state = false;
    ref.read(dotazVozidlaProvider.notifier).state = '';
    setState(() {});
    widget.onScan();
  }

  /// Skener po klepnutí na záložku - vůz se hledá podle SPZ nebo VINu
  /// ze štítku.
  /// Požadavek vystaví navigace; tady se vyzvedne a hned zahodí, takže po
  /// návratu ze skeneru ani po přepnutí zpět se znovu neotevře. Když je
  /// v hledání něco rozdělaného, skener se nespouští.
  void _vyzvedniPozadavek(WorkshopTab? pozadavek) {
    if (pozadavek != WorkshopTab.vyhledavani) return;
    // Mimo sestavování - stav providera se během něj měnit nesmí.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(pozadavekSkeneruProvider) != WorkshopTab.vyhledavani) return;
      ref.read(pozadavekSkeneruProvider.notifier).state = null;
      if (ref.read(dotazVozidlaProvider).trim().isNotEmpty) return;
      widget.onScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dotaz = ref.watch(dotazVozidlaProvider).trim();
    ref.listen(pozadavekSkeneruProvider, (_, novy) => _vyzvedniPozadavek(novy));
    // Ze skeneru přes „Zadat ručně" - kurzor do pole, ať jde hned psát.
    ref.listen(zadatRucneProvider, (_, novy) {
      if (novy != WorkshopTab.vyhledavani) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(zadatRucneProvider.notifier).state = null;
        _fokus.requestFocus();
      });
    });

    // Skener dotaz vyplní zvenčí - pole se musí srovnat.
    ref.listen(dotazVozidlaProvider, (_, novy) {
      if (novy == _odeslanyDotaz) return;
      _odeslanyDotaz = novy;
      _debounce?.cancel();
      _pole.text = novy;
      setState(() {});
    });

    // Hledání ze skeneru - do popisku na kartě.
    final naskenovano = ref.watch(otevritJedineVozidloProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _Hlavicka(
            pole: _pole,
            fokus: _fokus,
            onPsani: _psani,
            onScan: widget.onScan,
          ),
          Expanded(
            child: dotaz.length < nejkratsiDotazVozidla
                ? const _Sdeleni(
                    ikona: Icons.directions_car_outlined,
                    titulek: 'Najděte vozidlo',
                    text:
                        'Naskenujte SPZ fotoaparátem, nebo napište SPZ či VIN. '
                        'Ukáže se vůz, jeho majitel a všechny zakázky.',
                  )
                : ref
                      .watch(hledaniVozidelProvider(dotaz))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (chyba, _) => _Sdeleni(
                          ikona: Icons.cloud_off_rounded,
                          titulek: 'Hledání se nezdařilo',
                          text: '$chyba',
                        ),
                        data: (vozidla) => vozidla.isEmpty
                            ? const _Sdeleni(
                                ikona: Icons.search_off_rounded,
                                titulek: 'Vozidlo nenalezeno',
                                text:
                                    'Zkontrolujte SPZ nebo zkuste VIN - '
                                    'SPZ se při přeregistraci mění.',
                              )
                            : _Nalezena(
                                vozidla: vozidla,
                                naskenovano: naskenovano,
                                vybraneId: widget.vybraneId,
                                onOtevrit: widget.onOpenVozidlo,
                                onNeniToOno: _neniToOno,
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Hlavicka extends StatelessWidget {
  const _Hlavicka({
    required this.pole,
    required this.fokus,
    required this.onPsani,
    required this.onScan,
  });

  final TextEditingController pole;
  final FocusNode fokus;
  final ValueChanged<String> onPsani;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
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
            'Vyhledat vozidlo',
            style: AppTextStyles.appBarTitle(
              isIOS: context.isIOS,
            ).copyWith(color: Colors.white),
          ),
          const SizedBox(height: Insets.lg),
          OrderSearchField(
            controller: pole,
            focusNode: fokus,
            onChanged: onPsani,
            onScan: onScan,
            hintText: 'SPZ nebo VIN',
          ),
        ],
      ),
    );
  }
}

/// Výsledek hledání: jeden vůz jako karta se všemi údaji uprostřed,
/// víc vozů (přeregistrovaná SPZ, část značky napsaná rukou) pod sebou
/// k výběru.
class _Nalezena extends StatelessWidget {
  const _Nalezena({
    required this.vozidla,
    required this.naskenovano,
    required this.vybraneId,
    required this.onOtevrit,
    required this.onNeniToOno,
  });

  final List<NalezeneVozidlo> vozidla;
  final bool naskenovano;
  final int? vybraneId;
  final void Function(NalezeneVozidlo vozidlo) onOtevrit;
  final VoidCallback onNeniToOno;

  static const _odsazeni = EdgeInsets.fromLTRB(
    Insets.xl,
    Insets.xl,
    Insets.xl,
    Insets.giant,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget karta(NalezeneVozidlo vozidlo, {required bool jedno}) =>
        IdentifikaceVozidlaKarta(
          vozidlo: vozidlo,
          naskenovano: naskenovano,
          jeVybrane: vybraneId == vozidlo.id,
          onOtevrit: () => onOtevrit(vozidlo),
          onNeniToOno: jedno ? onNeniToOno : null,
        );

    if (vozidla.length == 1) {
      return Center(
        child: SingleChildScrollView(
          padding: _odsazeni,
          child: karta(vozidla.single, jedno: true),
        ),
      );
    }

    // Líně po jednom - každá karta si dočítá podrobnosti ze serveru
    // a hledání jich vrátí až dvacet.
    return ListView.builder(
      padding: _odsazeni,
      itemCount: vozidla.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Insets.xl),
            child: Text(
              '${pocetNalezenychVozidel(vozidla.length)} - vyberte to správné',
              key: const Key('vice-vozidel'),
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          );
        }
        if (index == vozidla.length + 1) {
          return Center(
            child: TextButton(
              key: const Key('nic-z-toho'),
              onPressed: onNeniToOno,
              child: const Text('Žádné z nich - skenovat znovu'),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.huge),
          child: Center(child: karta(vozidla[index - 1], jedno: false)),
        );
      },
    );
  }
}

/// „Nalezena 2 vozidla", „Nalezeno 5 vozidel" - čeština skloňuje podle
/// počtu.
String pocetNalezenychVozidel(int pocet) => switch (pocet) {
  1 => 'Nalezeno 1 vozidlo',
  >= 2 && <= 4 => 'Nalezena $pocet vozidla',
  _ => 'Nalezeno $pocet vozidel',
};

class _Sdeleni extends StatelessWidget {
  const _Sdeleni({
    required this.ikona,
    required this.titulek,
    required this.text,
  });

  final IconData ikona;
  final String titulek;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
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
          ],
        ),
      ),
    );
  }
}
