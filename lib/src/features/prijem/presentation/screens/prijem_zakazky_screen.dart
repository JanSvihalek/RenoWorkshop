import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/hlavicka_zakazky.dart';
import '../../../fotodokumentace/presentation/widgets/fotodokumentace_karta.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../domain/entities/prijem.dart';
import '../controllers/prijem_providers.dart';

/// Příjem vozidla u zakázky: checklist kontrol a fotodokumentace.
///
/// Každé zaškrtnutí se ukládá hned - technik obchází vůz s telefonem
/// v ruce a nemá myslet na „Uložit". Dokončit jde, až je checklist
/// vyplněný; dokončený příjem je zamčený, dokud ho někdo neotevře.
class PrijemZakazkyScreen extends ConsumerWidget {
  const PrijemZakazkyScreen({
    super.key,
    required this.orderId,
    required this.onBack,
    required this.onFotodokumentace,
  });

  final String orderId;
  final VoidCallback onBack;
  final VoidCallback onFotodokumentace;

  PrijemController _controller(WidgetRef ref) =>
      ref.read(prijemZakazkyProvider(orderId).notifier);

  void _ukazChybu(BuildContext context, String? chyba) {
    if (chyba == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(chyba)));
  }

  Future<void> _zmen(
    BuildContext context,
    WidgetRef ref,
    String kod,
    ZmenaPolozky zmena,
  ) async {
    final chyba = await _controller(ref).zmen(kod, zmena);
    if (context.mounted) _ukazChybu(context, chyba);
  }

  Future<void> _vyberDatum(
    BuildContext context,
    WidgetRef ref,
    PolozkaPrijmu polozka,
  ) async {
    final dnes = DateTime.now();
    final datum = await showDatePicker(
      context: context,
      initialDate: polozka.datum ?? dnes,
      // Propadlá STK je taky údaj, který je potřeba zapsat.
      firstDate: DateTime(dnes.year - 10),
      lastDate: DateTime(dnes.year + 10),
      helpText: polozka.nazev,
    );
    if (datum == null || !context.mounted) return;
    await _zmen(context, ref, polozka.kod, ZmenaPolozky.datum(datum));
  }

  Future<void> _upravPoznamku(
    BuildContext context,
    WidgetRef ref,
    PolozkaPrijmu polozka,
  ) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _PoznamkaDialog(
        nazev: polozka.nazev,
        poznamka: polozka.poznamka ?? '',
      ),
    );
    if (text == null || text.trim() == (polozka.poznamka ?? '')) return;
    if (!context.mounted) return;
    await _zmen(context, ref, polozka.kod, ZmenaPolozky.poznamka(text));
  }

  Future<void> _dokonci(BuildContext context, WidgetRef ref) async {
    final chyba = await _controller(ref).dokonci();
    if (!context.mounted) return;
    if (chyba != null) return _ukazChybu(context, chyba);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$orderId · příjem dokončen')));
  }

  Future<void> _znovuOtevri(BuildContext context, WidgetRef ref) async {
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
    if (!(potvrzeno ?? false) || !context.mounted) return;
    final chyba = await _controller(ref).znovuOtevri();
    if (context.mounted) _ukazChybu(context, chyba);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final zakazka = ref.watch(orderByIdProvider(orderId)).valueOrNull;
    final prijem = ref.watch(prijemZakazkyProvider(orderId));

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          HlavickaZakazky(
            nadpis: 'Příjem vozidla',
            onBack: onBack,
            cisloZakazky: orderId,
            spz: zakazka?.licensePlate,
            model: zakazka?.model,
          ),
          Expanded(
            child: prijem.when(
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (chyba, _) => _Chyba(
                zprava: '$chyba',
                onZnovu: () => ref.invalidate(prijemZakazkyProvider(orderId)),
              ),
              data: (prijem) => ListView(
                padding: EdgeInsets.fromLTRB(
                  Insets.xl,
                  Insets.lg,
                  Insets.xl,
                  Insets.giant + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (prijem.jeDokoncen) ...[
                    _Dokonceno(
                      prijem: prijem,
                      onZnovuOtevrit: () => _znovuOtevri(context, ref),
                    ),
                    const SizedBox(height: Insets.base),
                  ],
                  DetailCard(
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
                            const Expanded(
                              child: SectionLabel('KONTROLA PŘI PŘÍJMU'),
                            ),
                            Text(
                              '${prijem.pocetVyplnenych} / ${prijem.pocetPovinnych}',
                              key: const Key('prijem-postup'),
                              style: AppTextStyles.chip.copyWith(
                                color: prijem.chybi == 0
                                    ? AppColors.readyGreen
                                    : palette.muted,
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
                            onZaskrtnout: (hodnota) => _zmen(
                              context,
                              ref,
                              polozka.kod,
                              ZmenaPolozky.splneno(hodnota),
                            ),
                            onDatum: () => _vyberDatum(context, ref, polozka),
                            onPoznamka: () =>
                                _upravPoznamku(context, ref, polozka),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.base),
                  FotodokumentaceKarta(
                    orderId: orderId,
                    onOtevrit: onFotodokumentace,
                  ),
                  if (!prijem.jeDokoncen) ...[
                    const SizedBox(height: Insets.xl),
                    SizedBox(
                      height: Sizes.ctaHeight,
                      child: FilledButton.icon(
                        key: const Key('dokoncit-prijem'),
                        onPressed: prijem.chybi == 0
                            ? () => _dokonci(context, ref)
                            : null,
                        icon: const Icon(Icons.task_alt_rounded),
                        label: Text(
                          prijem.chybi == 0
                              ? 'Dokončit příjem'
                              : 'Zbývá zkontrolovat: ${prijem.chybi}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
