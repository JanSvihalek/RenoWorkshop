import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/presentation/widgets/order_search_field.dart';
import '../../../orders/presentation/widgets/plate_chip.dart';
import '../../domain/entities/vozidlo.dart';
import '../controllers/vozidla_providers.dart';
import '../../../../core/navigace/pozadavek_skeneru.dart';
import '../../../../core/widgets/workshop_bottom_nav.dart';

/// Vyhledání vozidla podle SPZ nebo VIN.
///
/// Typicky se SPZ naskenuje - jediný výsledek se pak otevře rovnou.
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
      // Psaní rukou nikdy neotvírá kartu samo - viz otevritJedineVozidlo.
      ref.read(otevritJedineVozidloProvider.notifier).state = false;
      _odeslanyDotaz = text;
      ref.read(dotazVozidlaProvider.notifier).state = text;
    });
    setState(() {});
  }

  void _otevriJedine(List<NalezeneVozidlo>? vozidla) {
    if (vozidla == null || !ref.read(otevritJedineVozidloProvider)) return;
    // Navigace nesmí proběhnout uprostřed sestavování obrazovky.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(otevritJedineVozidloProvider)) return;
      ref.read(otevritJedineVozidloProvider.notifier).state = false;
      if (vozidla.length == 1) widget.onOpenVozidlo(vozidla.single);
    });
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

    // Po naskenování: jediný výsledek rovnou otevřít. Jednak až výsledek
    // dorazí, jednak hned, když už je načtený - při opakovaném naskenování
    // téže SPZ by žádná změna nepřišla.
    if (dotaz.length >= nejkratsiDotazVozidla) {
      final hledani = hledaniVozidelProvider(dotaz);
      ref.listen(hledani, (_, vysledek) => _otevriJedine(vysledek.valueOrNull));
      _otevriJedine(ref.read(hledani).valueOrNull);
    }

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
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  Insets.xl,
                                  Insets.lg,
                                  Insets.xl,
                                  Insets.giant,
                                ),
                                itemCount: vozidla.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: Insets.md),
                                itemBuilder: (_, index) => _RadekVozidla(
                                  vozidlo: vozidla[index],
                                  jeVybrane:
                                      widget.vybraneId == vozidla[index].id,
                                  onTap: () =>
                                      widget.onOpenVozidlo(vozidla[index]),
                                ),
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

class _RadekVozidla extends StatelessWidget {
  const _RadekVozidla({
    required this.vozidlo,
    required this.jeVybrane,
    required this.onTap,
  });

  final NalezeneVozidlo vozidlo;
  final bool jeVybrane;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Vozidlo ${vozidlo.spz}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: jeVybrane ? AppColors.accent : palette.hairline,
              width: jeVybrane ? 2 : 1,
            ),
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
