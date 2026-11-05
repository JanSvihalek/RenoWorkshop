import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/akce_providers.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../domain/kapacita.dart';
import '../domain/prehled_planu.dart';
import 'plan_providers.dart';

/// Kapacita dílen pobočky: kdo kam patří, kdy chybí a ručně zadané dny. Změna
/// se uloží hned a plán se přepočítá. Otevře ji jen ten, kdo má právo Kapacita.
class KapacitaScreen extends ConsumerStatefulWidget {
  const KapacitaScreen({super.key, required this.pobocka, required this.nazev});

  final String pobocka;
  final String nazev;

  @override
  ConsumerState<KapacitaScreen> createState() => _KapacitaScreenState();
}

class _KapacitaScreenState extends ConsumerState<KapacitaScreen> {
  JednotkaKapacity _jednotka = JednotkaKapacity.hodiny;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pobocka = widget.pobocka;
    final prehled = ref.watch(kapacitaProvider(pobocka));
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Kapacita dílen · ${widget.nazev}',
          style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
        ),
      ),
      body: prehled.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (chyba, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Text(
              chyba is ServiceOrderException
                  ? chyba.message
                  : 'Kapacitu se nepodařilo načíst.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          ),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.xl,
            Insets.sm,
            Insets.xl,
            Insets.giant,
          ),
          children: [
            Text(
              'Součet přítomných lidí, každý má výchozích 7,5 h (90 AW). '
              'Ručně zadaný den má přednost.',
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.md),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<JednotkaKapacity>(
                key: const Key('kapacita-jednotka'),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: JednotkaKapacity.hodiny,
                    label: Text('Hodiny'),
                  ),
                  ButtonSegment(value: JednotkaKapacity.aw, label: Text('AW')),
                ],
                selected: {_jednotka},
                onSelectionChanged: (v) => setState(() => _jednotka = v.first),
              ),
            ),
            const SizedBox(height: Insets.lg),
            _Nadpis('LIDÉ'),
            if (p.lide.isEmpty)
              Text(
                'Na středisku teď není nikdo s tarifem Mechanik, Karosář nebo Lakýrník.',
                style: AppTextStyles.cardBody.copyWith(color: palette.muted),
              )
            else
              _Karta(
                deti: [
                  for (final c in p.lide)
                    _RadekCloveka(
                      clovek: c,
                      pobocka: pobocka,
                      jednotka: _jednotka,
                    ),
                ],
              ),
            const SizedBox(height: Insets.xl),
            _Nadpis('RUČNĚ ZADANÝ DEN'),
            _RucniDen(pobocka: pobocka, jednotka: _jednotka),
            for (final d in p.dny) _UlozenyDen(den: d, pobocka: pobocka),
          ],
        ),
      ),
    );
  }
}

/// Kapacita člověka v zadané jednotce a vedle přepočet na tu druhou.
String _textKapacity(int aw, JednotkaKapacity jednotka) {
  final hodiny = '${hodinyText(aw / awZaHodinu)} h';
  return jednotka == JednotkaKapacity.hodiny
      ? '$hodiny · $aw AW'
      : '$aw AW · $hodiny';
}

/// Změna kapacity: uloží, přepočítá okno i plán, chybu ukáže dole.
Future<void> _zapis(
  BuildContext context,
  WidgetRef ref,
  String pobocka,
  Future<void> Function() zapis,
) async {
  try {
    await zapis();
    ref.invalidate(kapacitaProvider(pobocka));
    ref.invalidate(planKlempirnyProvider);
  } on ServiceOrderException catch (chyba) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(chyba.message)));
  }
}

class _Nadpis extends StatelessWidget {
  const _Nadpis(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Insets.xxs, bottom: Insets.sm),
    child: Text(
      text,
      style: AppTextStyles.overline.copyWith(color: context.palette.muted),
    ),
  );
}

class _Karta extends StatelessWidget {
  const _Karta({required this.deti});

  final List<Widget> deti;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, d) in deti.indexed) ...[
            if (i > 0) Divider(height: 1, color: palette.hairline),
            d,
          ],
        ],
      ),
    );
  }
}

class _RadekCloveka extends ConsumerWidget {
  const _RadekCloveka({
    required this.clovek,
    required this.pobocka,
    required this.jednotka,
  });

  final ClovekKapacity clovek;
  final String pobocka;
  final JednotkaKapacity jednotka;

  Future<void> _upravKapacitu(BuildContext context, WidgetRef ref) async {
    final aw = await showDialog<int>(
      context: context,
      builder: (_) => _OknoKapacityCloveka(clovek: clovek, jednotka: jednotka),
    );
    if (aw == null || aw == clovek.awDen || !context.mounted) return;
    await _zapis(
      context,
      ref,
      pobocka,
      () =>
          ref.read(planDataSourceProvider).nastavKapacituCloveka(clovek.id, aw),
    );
  }

  Future<void> _pridejNepritomnost(BuildContext context, WidgetRef ref) async {
    final dnes = ref.read(dnesProvider);
    final vybrano = await showDateRangePicker(
      context: context,
      firstDate: dnes.subtract(const Duration(days: 365)),
      lastDate: dnes.add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: dnes, end: dnes),
      currentDate: dnes,
      helpText: 'Nepřítomnost od – do',
      saveText: 'Použít',
    );
    if (vybrano == null || !context.mounted) return;
    await _zapis(
      context,
      ref,
      pobocka,
      () => ref
          .read(planDataSourceProvider)
          .pridejNepritomnost(clovek.id, vybrano.start, vybrano.end),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vychozi = clovek.dilnaPodleTarifu;
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clovek.popisek,
                      style: AppTextStyles.cardBody.copyWith(
                        color: clovek.dilna == null
                            ? palette.muted
                            : palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      clovek.tarify.join(', '),
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              DropdownButton<String>(
                key: Key('kapacita-zarazeni-${clovek.id}'),
                value: clovek.prirazeno ?? vychozi?.kod,
                underline: const SizedBox.shrink(),
                items: [
                  for (final d in Dilna.values)
                    DropdownMenuItem(value: d.kod, child: Text(d.nazev)),
                  const DropdownMenuItem(
                    value: zarazeniMimo,
                    child: Text('Nepočítat'),
                  ),
                ],
                onChanged: (hodnota) => _zapis(
                  context,
                  ref,
                  pobocka,
                  () => ref
                      .read(planDataSourceProvider)
                      // Stejné jako podle tarifu = žádná výjimka.
                      .zaradCloveka(
                        clovek.id,
                        hodnota == vychozi?.kod ? null : hodnota,
                      ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: Insets.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                key: Key('kapacita-clovek-${clovek.id}'),
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(_textKapacity(clovek.awDen, jednotka)),
                tooltip: 'Kapacita za den',
                onPressed: () => _upravKapacitu(context, ref),
              ),
              for (final n in clovek.nepritomnosti)
                InputChip(
                  key: Key('kapacita-nepritomnost-${n.id}'),
                  label: Text(
                    n.od == n.do_
                        ? AppDateFormat.dayMonth(n.od)
                        : '${AppDateFormat.dayMonth(n.od)} – '
                              '${AppDateFormat.dayMonth(n.do_)}',
                  ),
                  deleteButtonTooltipMessage: 'Smazat nepřítomnost',
                  onDeleted: () => _zapis(
                    context,
                    ref,
                    pobocka,
                    () =>
                        ref.read(planDataSourceProvider).smazNepritomnost(n.id),
                  ),
                ),
              TextButton(
                key: Key('kapacita-pridat-${clovek.id}'),
                onPressed: () => _pridejNepritomnost(context, ref),
                child: const Text('Nepřítomnost'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Zadání kapacity člověka za den. Vrací AW; zavření bez uložení `null`.
class _OknoKapacityCloveka extends StatefulWidget {
  const _OknoKapacityCloveka({required this.clovek, required this.jednotka});

  final ClovekKapacity clovek;
  final JednotkaKapacity jednotka;

  @override
  State<_OknoKapacityCloveka> createState() => _OknoKapacityClovekaState();
}

class _OknoKapacityClovekaState extends State<_OknoKapacityCloveka> {
  late final TextEditingController _hodnota = TextEditingController(
    text: hodnotaKapacity(widget.clovek.awDen, widget.jednotka),
  );

  @override
  void dispose() {
    _hodnota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hodiny = widget.jednotka == JednotkaKapacity.hodiny;
    final aw = kapacitaClovekaNaAw(_hodnota.text, widget.jednotka);
    return AlertDialog(
      title: Text(widget.clovek.popisek),
      content: TextField(
        key: const Key('kapacita-clovek-hodnota'),
        controller: _hodnota,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Kapacita za den',
          suffixText: hodiny ? 'h' : 'AW',
          helperText: aw == null
              ? null
              : hodiny
              ? '$aw AW'
              : '${hodinyText(aw / awZaHodinu)} h',
          errorText: aw == null ? 'Od 1 AW do 24 h' : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(
          key: const Key('kapacita-clovek-vychozi'),
          onPressed: () => Navigator.of(context).pop(awClovekDen),
          child: Text('Výchozí ${hodinyText(awClovekDen / awZaHodinu)} h'),
        ),
        FilledButton(
          key: const Key('kapacita-clovek-ulozit'),
          onPressed: aw == null ? null : () => Navigator.of(context).pop(aw),
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}

class _RucniDen extends ConsumerStatefulWidget {
  const _RucniDen({required this.pobocka, required this.jednotka});

  final String pobocka;
  final JednotkaKapacity jednotka;

  @override
  ConsumerState<_RucniDen> createState() => _RucniDenState();
}

class _RucniDenState extends ConsumerState<_RucniDen> {
  final _hodnota = TextEditingController();
  DateTime? _den;
  Dilna _dilna = Dilna.klempirna;

  @override
  void dispose() {
    _hodnota.dispose();
    super.dispose();
  }

  Future<void> _vyberDen(DateTime den) async {
    final dnes = ref.read(dnesProvider);
    final vybrano = await showDatePicker(
      context: context,
      firstDate: dnes.subtract(const Duration(days: 365)),
      lastDate: dnes.add(const Duration(days: 730)),
      initialDate: den,
      currentDate: dnes,
    );
    if (vybrano != null) setState(() => _den = vybrano);
  }

  @override
  Widget build(BuildContext context) {
    final dnes = ref.watch(dnesProvider);
    final den = _den ?? DateTime(dnes.year, dnes.month, dnes.day);
    final aw = prevedNaAw(_hodnota.text, widget.jednotka);
    final spatne = _hodnota.text.trim().isNotEmpty && aw == null;
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const Key('kapacita-den'),
          onPressed: () => _vyberDen(den),
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text(AppDateFormat.date(den)),
        ),
        DropdownButton<Dilna>(
          key: const Key('kapacita-dilna'),
          value: _dilna,
          underline: const SizedBox.shrink(),
          items: [
            for (final d in Dilna.values)
              DropdownMenuItem(value: d, child: Text(d.nazev)),
          ],
          onChanged: (d) => setState(() => _dilna = d ?? _dilna),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            key: const Key('kapacita-hodnota'),
            controller: _hodnota,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.jednotka == JednotkaKapacity.hodiny
                  ? '15'
                  : '180',
              suffixText: widget.jednotka == JednotkaKapacity.hodiny
                  ? 'h'
                  : 'AW',
              errorText: spatne ? 'Neplatné' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        FilledButton(
          key: const Key('kapacita-ulozit-den'),
          onPressed: aw == null
              ? null
              : () async {
                  await _zapis(
                    context,
                    ref,
                    widget.pobocka,
                    () => ref
                        .read(planDataSourceProvider)
                        .ulozKapacituDne(widget.pobocka, den, _dilna, aw),
                  );
                  _hodnota.clear();
                  if (mounted) setState(() {});
                },
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}

class _UlozenyDen extends ConsumerWidget {
  const _UlozenyDen({required this.den, required this.pobocka});

  final RucniDenKapacity den;
  final String pobocka;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${AppDateFormat.date(den.den)} · ${den.dilna.nazev} · '
              '${hodinyText(den.aw / awZaHodinu)} h (${den.aw} AW)'
              '${den.kdo == null ? '' : ' · ${den.kdo}'}',
              style: AppTextStyles.metaSmall.copyWith(color: palette.text),
            ),
          ),
          TextButton(
            key: Key(
              'kapacita-podle-lidi-${den.den.toIso8601String().substring(0, 10)}'
              '-${den.dilna.kod}',
            ),
            onPressed: () => _zapis(
              context,
              ref,
              pobocka,
              () => ref
                  .read(planDataSourceProvider)
                  .ulozKapacituDne(pobocka, den.den, den.dilna, null),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Podle lidí'),
          ),
        ],
      ),
    );
  }
}
