import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/prani_zakaznika.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/zavada.dart';
import '../controllers/order_actions_controller.dart';
import '../controllers/orders_providers.dart';
import 'detail_cards.dart';
import 'okno_zapisu.dart';
import 'pridat_stav_sheet.dart';

const _oranzova = Color(0xFFE8A93A);

/// Závady z Heliosu a ruční úkony v jednom seznamu - co má dílna na voze
/// udělat. Závady zapisuje poradce v Heliosu, ruční úkony dílna a do Heliosu
/// se nepřenášejí. U obojího se zapisuje Zahájit a Dokončit jako dílenské
/// stavy, takže jsou vidět i v průběhu opravy.
class ZavadyCard extends ConsumerWidget {
  const ZavadyCard({super.key, required this.order});

  final ServiceOrder order;

  Future<void> _pridatUkon(BuildContext context, WidgetRef ref) async {
    final vysledek = await showDialog<({String nazev, String poznamka})>(
      context: context,
      builder: (_) => _NovyUkonDialog(
        spz: order.licensePlate,
        cisloZakazky: order.id,
        autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
      ),
    );
    if (vysledek == null) return;
    await ref
        .read(orderActionsProvider.notifier)
        .pridejRucniUkon(
          order.id,
          nazev: vysledek.nazev,
          poznamka: vysledek.poznamka,
        );
  }

  Future<void> _smazatUkon(
    BuildContext context,
    WidgetRef ref,
    RucniUkon ukon,
  ) async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Smazat úkon?'),
        content: Text(
          'Úkon „${ukon.nazev}" zmizí ze seznamu. Co se už zapsalo do '
          'průběhu, zůstane.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Zrušit'),
          ),
          FilledButton(
            key: const Key('ukon-smazat-potvrdit'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (potvrzeno != true) return;
    await ref
        .read(orderActionsProvider.notifier)
        .smazRucniUkon(order.id, ukon.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final zavady = order.zavady;
    final rucni = order.rucniUkony;
    // Stejná práva jako průběh opravy, do kterého se úkon zapisuje.
    final smi =
        ref.watch(smiPlanovatProvider(order.branch?.code)) ||
        ref.watch(smiZapisovatProvider(order.poradac?.kod));
    final souhrn = [
      if (zavady.isNotEmpty) '${zavady.length} z Heliosu',
      if (rucni.isNotEmpty) '${rucni.length} ručně mimo Helios',
    ].join(' · ');

    return DetailCard(
      key: const Key('zavady-karta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: Insets.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const SectionLabel('ZÁVADY/ÚKONY'),
                    if (zavady.length + rucni.length > 0)
                      Text(
                        '${zavady.length + rucni.length}',
                        style: AppTextStyles.orderNumber.copyWith(
                          fontSize: 11.5,
                          color: palette.muted,
                        ),
                      ),
                    if (souhrn.isNotEmpty)
                      Text(
                        '· $souhrn',
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (smi) ...[
                const SizedBox(width: Insets.sm),
                OutlinedButton.icon(
                  key: const Key('pridat-ukon'),
                  onPressed: () => _pridatUkon(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Přidat úkon'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.base,
                    ),
                    foregroundColor: AppColors.accent,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppColors.accent),
                    textStyle: AppTextStyles.chip,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.base),
          if (zavady.isEmpty && rucni.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.base),
              child: Text(
                'V Heliosu nejsou u zakázky zapsané žádné závady.',
                style: AppTextStyles.cardBody.copyWith(color: palette.muted),
              ),
            ),
          for (final (poradi, zavada) in zavady.indexed)
            _RadekUkonu(
              id: zavada.id,
              poradi: poradi + 1,
              nazev: zavada.nazev,
              poznamka: zavada.text.trim(),
              kod: zavada.kod,
              prubeh: stavZavady(zavada.id, order.historieStavu),
              order: order,
              smi: smi,
              onZahajit: () =>
                  pridatStavZakazce(context, ref, order, zavada: zavada),
            ),
          for (final (poradi, ukon) in rucni.indexed)
            _RadekUkonu(
              id: ukon.id,
              poradi: zavady.length + poradi + 1,
              nazev: ukon.nazev,
              poznamka: ukon.poznamka?.trim() ?? '',
              rucni: true,
              doplnek: _kdoPridal(ukon),
              prubeh: stavZavady(ukon.id, order.historieStavu, rucni: true),
              order: order,
              smi: smi,
              onZahajit: () =>
                  pridatStavZakazce(context, ref, order, rucniUkon: ukon),
              onSmazat: () => _smazatUkon(context, ref, ukon),
            ),
          _OstatniPrani(prani: order.prani),
        ],
      ),
    );
  }

  static String _kdoPridal(RucniUkon ukon) {
    final kdy = ukon.pridano;
    return [
      'přidal ${ukon.pridal ?? 'neznámý'}',
      if (kdy != null)
        '${AppDateFormat.dayMonthSmart(kdy)} ${AppDateFormat.time(kdy)}',
    ].join(' ');
  }
}

/// Zelená dokončeného úkonu - stejné odstíny jako „Zápis" a pásmo
/// vytížení pod 50 % (web `--vyt-nizke*`).
({Color znacka, Color pozadi, Color text}) _zelena(BuildContext context) {
  final tmava = context.isDarkMode;
  return (
    znacka: tmava ? const Color(0xFF5FD38D) : const Color(0xFF2E9E5B),
    pozadi: tmava ? const Color(0x295FD38D) : const Color(0xFFE3F5EA),
    text: tmava ? const Color(0xFF5FD38D) : const Color(0xFF1B6E3C),
  );
}

/// Jeden řádek seznamu - závada z Heliosu, nebo ruční úkon.
class _RadekUkonu extends ConsumerWidget {
  const _RadekUkonu({
    required this.id,
    required this.poradi,
    required this.nazev,
    required this.poznamka,
    required this.prubeh,
    required this.order,
    required this.smi,
    required this.onZahajit,
    this.kod,
    this.rucni = false,
    this.doplnek,
    this.onSmazat,
  });

  final String id;
  final int poradi;
  final String? nazev;
  final String poznamka;
  final String? kod;
  final bool rucni;
  final String? doplnek;
  final StavZavady prubeh;
  final ServiceOrder order;
  final bool smi;
  final VoidCallback onZahajit;
  final VoidCallback? onSmazat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final zaneprazdneno = ref.watch(orderActionsProvider).isLoading;
    final klic = rucni ? 'ukon' : 'zavada';
    final prubeh = this.prubeh;
    final nazev = this.nazev;
    final kod = this.kod;

    // Stručný popis tučně, podrobnosti z poznámky pod ním menším písmem.
    // Starší závady bez popisu mají jen poznámku - ta pak zastoupí popis.
    final titulek = nazev ?? (poznamka.isEmpty ? 'Bez popisu' : poznamka);
    final styleStavu = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    // Dokončený úkon zezelená a má fajfku vpravo - stejně jako na webu.
    final hotovo = prubeh is ZavadaHotova;
    final zelena = _zelena(context);

    final tlacitkoZahajit = OutlinedButton(
      key: Key('$klic-zahajit-$id'),
      onPressed: onZahajit,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: Insets.base),
        textStyle: AppTextStyles.chip,
      ),
      child: const Text('Zahájit'),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: hotovo ? zelena.pozadi : null,
          border: Border.all(color: hotovo ? zelena.znacka : palette.hairline2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(Insets.base),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$poradi.',
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: Insets.sm,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SelectableText(
                              titulek,
                              style: AppTextStyles.cardBody.copyWith(
                                color: palette.text,
                                fontWeight: nazev != null
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                            _ZnackaZdroje(rucni: rucni),
                          ],
                        ),
                        if (nazev != null &&
                            poznamka.isNotEmpty &&
                            poznamka != nazev) ...[
                          const SizedBox(height: 2),
                          SelectableText(
                            poznamka,
                            style: AppTextStyles.metaSmall.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                        // Kód z Heliosu bývá jen pořadové číslo.
                        if (kod != null &&
                            !RegExp(r'^\d+$').hasMatch(kod.trim())) ...[
                          const SizedBox(height: 2),
                          Text('Závada $kod', style: styleStavu),
                        ],
                        const SizedBox(height: 2),
                        Wrap(
                          children: [
                            switch (prubeh) {
                              ZavadaProbiha() => Text(
                                'Probíhá',
                                key: Key('$klic-probiha-$id'),
                                style: styleStavu.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              ZavadaHotova(:final kdy) => Text(
                                'Dokončeno ${AppDateFormat.date(kdy)}',
                                key: Key('$klic-hotovo-$id'),
                                style: styleStavu.copyWith(
                                  color: zelena.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              ZavadaCeka(:final preruseno) => Text(
                                preruseno ? 'Přerušeno' : 'Nezahájeno',
                                style: styleStavu,
                              ),
                            },
                            if (doplnek case final doplnek?)
                              Text(' · $doplnek', style: styleStavu),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hotovo) ...[
                    const SizedBox(width: Insets.sm),
                    Tooltip(
                      message: 'Dokončeno',
                      child: Container(
                        key: Key('$klic-fajfka-$id'),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: zelena.znacka,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: palette.card,
                        ),
                      ),
                    ),
                  ],
                  if (smi) ...[
                    const SizedBox(width: Insets.sm),
                    if (prubeh is ZavadaCeka) tlacitkoZahajit,
                    if (prubeh is ZavadaProbiha)
                      FilledButton(
                        key: Key('$klic-dokoncit-$id'),
                        onPressed: zaneprazdneno
                            ? null
                            : () => ref
                                  .read(orderActionsProvider.notifier)
                                  .dokonciStav(order.id, prubeh.zaznamId),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.base,
                          ),
                          // Tmavomodrá by na tmavém pozadí zanikla.
                          backgroundColor: context.isDarkMode
                              ? AppColors.accent
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          textStyle: AppTextStyles.chip,
                        ),
                        child: const Text('Dokončit'),
                      ),
                    if (onSmazat case final smazat?)
                      PopupMenuButton<String>(
                        key: Key('ukon-menu-$id'),
                        icon: const Icon(Icons.more_horiz, size: 20),
                        tooltip: 'Další akce',
                        onSelected: (_) => smazat(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'smazat',
                            child: Text('Smazat úkon'),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            if (rucni)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(color: _oranzova),
              ),
          ],
        ),
      ),
    );
  }
}

/// Odkud úkon je - zamčený z Heliosu, nebo zapsaný ručně.
class _ZnackaZdroje extends StatelessWidget {
  const _ZnackaZdroje({required this.rucni});

  final bool rucni;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barva = !rucni
        ? palette.muted2
        : (context.isDarkMode ? _oranzova : const Color(0xFFB8740A));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: rucni ? _oranzova.withValues(alpha: 0.18) : palette.hairline,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rucni ? Icons.edit_outlined : Icons.lock_outline,
            size: 11,
            color: barva,
          ),
          const SizedBox(width: 3),
          Text(
            rucni ? 'RUČNĚ · MIMO HELIOS' : 'HELIOS',
            style: AppTextStyles.metaSmall.copyWith(
              color: barva,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Co má mechanik kromě závad udělat. Vždy všechno, ať je jasné i „Ne".
class _OstatniPrani extends StatelessWidget {
  const _OstatniPrani({required this.prani});

  final PraniZakaznika? prani;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final prani = this.prani;

    Widget polozka(String nazev, bool? ano, [String? doplnek]) {
      final hodnota = switch (ano) {
        null => 'Nezadáno',
        false => 'Ne',
        true => doplnek == null ? 'Ano' : 'Ano · $doplnek',
      };
      // Jeden text: na úzkém telefonu se zalomí místo přetečení.
      return Text.rich(
        TextSpan(
          text: '$nazev: ',
          style: AppTextStyles.cardBody.copyWith(color: palette.muted),
          children: [
            TextSpan(
              text: hodnota,
              style: TextStyle(
                color: ano == true ? palette.text : palette.muted,
                fontWeight: ano == true ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('prani-zakaznika'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Insets.xs),
        const Divider(height: 1),
        const SizedBox(height: Insets.base),
        Wrap(
          spacing: Insets.base,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SectionLabel('OSTATNÍ PŘÁNÍ'),
            polozka('Mytí', prani?.myti, prani?.mytiProgram),
            polozka('Vrátit vyměněné díly', prani?.vratitDily),
            polozka('Provozní kapaliny', prani?.provozniKapaliny),
          ],
        ),
      ],
    );
  }
}

class _NovyUkonDialog extends StatefulWidget {
  const _NovyUkonDialog({
    required this.spz,
    required this.cisloZakazky,
    required this.autor,
  });

  final String spz;
  final String cisloZakazky;
  final String autor;

  @override
  State<_NovyUkonDialog> createState() => _NovyUkonDialogState();
}

class _NovyUkonDialogState extends State<_NovyUkonDialog> {
  final _nazev = TextEditingController();
  final _poznamka = TextEditingController();

  @override
  void dispose() {
    _nazev.dispose();
    _poznamka.dispose();
    super.dispose();
  }

  bool get _lzeUlozit => _nazev.text.trim().isNotEmpty;

  void _uloz() {
    if (!_lzeUlozit) return;
    Navigator.of(
      context,
    ).pop((nazev: _nazev.text.trim(), poznamka: _poznamka.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return OknoZapisu(
      nadpis: 'Přidat úkon',
      kam: 'do závad a úkonů',
      spz: widget.spz,
      cisloZakazky: widget.cisloZakazky,
      autor: widget.autor,
      potvrdit: 'Přidat úkon',
      potvrditKey: const Key('novy-ukon-ulozit'),
      onPotvrdit: _lzeUlozit ? _uloz : null,
      obsah: [
        PoleZapisu(
          poleKey: const Key('novy-ukon-nazev'),
          controller: _nazev,
          napoveda: 'Název úkonu',
          maxDelka: 100,
          autofocus: true,
          minLines: 1,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Insets.md),
        PoleZapisu(
          poleKey: const Key('novy-ukon-poznamka'),
          controller: _poznamka,
          napoveda: 'Poznámka (nepovinné)',
          maxDelka: 500,
          minLines: 2,
          maxLines: 5,
        ),
      ],
    );
  }
}
