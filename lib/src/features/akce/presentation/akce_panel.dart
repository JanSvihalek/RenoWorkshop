import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../../orders/presentation/widgets/okno_zapisu.dart';
import '../domain/marketingova_akce.dart';
import 'akce_providers.dart';

/// „1 den", „3 dny", „5 dní".
String dni(int n) =>
    '$n ${n == 1
        ? 'den'
        : n >= 2 && n <= 4
        ? 'dny'
        : 'dní'}';

/// Kolik akcí - „1 marketingová akce", „3 marketingové akce", „5 …akcí".
String pocetAkci(int n) =>
    '$n ${n == 1
        ? 'marketingová akce'
        : n >= 2 && n <= 4
        ? 'marketingové akce'
        : 'marketingových akcí'}';

/// Platnost akce slovy a jestli je potřeba na ni upozornit (brzy končí).
(String, bool) stavAkce(MarketingovaAkce akce, DateTime dnes) {
  if (akce.zacne(dnes)) {
    final za = akce.zacneZa(dnes);
    return (za == 1 ? 'Začne zítra' : 'Začne za ${dni(za)}', false);
  }
  final zbyva = akce.zbyvaDni(dnes);
  if (zbyva <= 1) return ('Končí dnes', true);
  if (zbyva <= 7) return ('Končí za ${dni(zbyva - 1)}', true);
  return ('Platí ještě ${dni(zbyva)}', false);
}

String obdobi(MarketingovaAkce akce) {
  final stejnyRok = akce.od.year == akce.do_.year;
  final od = stejnyRok
      ? AppDateFormat.dayMonth(akce.od)
      : AppDateFormat.date(akce.od);
  return '$od – ${AppDateFormat.date(akce.do_)}';
}

/// Marketingové akce: časová osa a pod ní karty s textem. Na tabletu ve
/// sloupci vedle seznamu zakázek, na telefonu jako samostatná obrazovka.
class AkcePanel extends ConsumerWidget {
  const AkcePanel({super.key, this.napoveda, this.onZavrit});

  /// Řádek nad panelem - na tabletu „Vyberte zakázku ze seznamu".
  final String? napoveda;

  /// Křížek v hlavičce - panel vysunutý z postranní lišty.
  final VoidCallback? onZavrit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prehled = ref.watch(akceProvider);
    final dnes = ref.watch(dnesProvider);
    final muze = prehled.valueOrNull?.muzeUpravovat ?? false;

    return RefreshIndicator.adaptive(
      onRefresh: ref.read(akceProvider.notifier).obnov,
      child: ListView(
        key: const Key('akce-panel'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Insets.xxl,
          Insets.xl,
          Insets.xxl,
          Insets.huge,
        ),
        children: [
          if (napoveda != null) ...[
            Row(
              children: [
                Icon(Icons.west_rounded, size: 16, color: palette.muted),
                const SizedBox(width: Insets.sm),
                Text(
                  napoveda!,
                  style: AppTextStyles.metaSmall.copyWith(
                    fontSize: 13,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),
          ],
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 20, color: palette.text),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'Marketingové akce',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              if (muze)
                TextButton.icon(
                  key: const Key('akce-pridat'),
                  onPressed: () => upravitAkci(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Přidat akci'),
                ),
              if (onZavrit != null)
                IconButton(
                  key: const Key('akce-zavrit'),
                  onPressed: onZavrit,
                  tooltip: 'Zavřít',
                  icon: Icon(Icons.close_rounded, color: palette.muted2),
                ),
            ],
          ),
          const SizedBox(height: Insets.base),
          ...prehled.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(Insets.huge),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (chyba, _) => [
              Text(
                chyba is ServiceOrderException
                    ? chyba.message
                    : 'Akce se nepodařilo načíst.',
                style: AppTextStyles.cardBody.copyWith(color: palette.muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: ref.read(akceProvider.notifier).obnov,
                  child: const Text('Zkusit znovu'),
                ),
              ),
            ],
            data: (p) => p.akce.isEmpty
                ? [
                    Text(
                      'Žádné aktuální ani chystané akce.',
                      key: const Key('akce-zadne'),
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ]
                : [
                    _CasovaOsa(akce: p.akce, dnes: dnes),
                    const SizedBox(height: Insets.lg),
                    for (final akce in p.akce) ...[
                      _KartaAkce(
                        akce: akce,
                        dnes: dnes,
                        onUpravit: muze
                            ? () => upravitAkci(context, ref, akce: akce)
                            : null,
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

/// Akce jako pruhy na časové ose od týdne zpátky po osm týdnů dopředu,
/// s čarou dneška - na první pohled je vidět, co platí, co brzy končí
/// a co teprve začne.
class _CasovaOsa extends StatelessWidget {
  const _CasovaOsa({required this.akce, required this.dnes});

  final List<MarketingovaAkce> akce;
  final DateTime dnes;

  static const _dniZpet = 7;
  static const _dniDopredu = 56;
  static const _vyskaRadku = 30.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final zacatek = dnes.subtract(const Duration(days: _dniZpet));
    const dnu = _dniZpet + _dniDopredu;
    final konec = zacatek.add(const Duration(days: dnu));
    final naOse = [
      for (final a in akce)
        if (!a.od.isAfter(konec)) a,
    ];
    // Pondělí na ose - popisky týdnů.
    final pondeli = [
      for (var i = 0; i < dnu; i++)
        if (zacatek.add(Duration(days: i)).weekday == DateTime.monday) i,
    ];

    return Container(
      key: const Key('akce-osa'),
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.base,
        Insets.lg,
        Insets.lg,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sirka = constraints.maxWidth;
          final den = sirka / dnu;
          double x(DateTime d) => d.difference(zacatek).inDays * den;
          final vyska = 22 + naOse.length * _vyskaRadku;

          return SizedBox(
            height: vyska,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Týdny - tenká čára a datum pondělí.
                for (final (poradi, i) in pondeli.indexed) ...[
                  Positioned(
                    left: i * den,
                    top: 18,
                    bottom: 0,
                    child: Container(width: 1, color: palette.hairline),
                  ),
                  // Na úzké ose jen každý druhý týden a nic těsně u dneška
                  // - popisky by se slily.
                  if ((den * 7 >= 52 || poradi.isEven) &&
                      (i * den - x(dnes)).abs() > 40)
                    Positioned(
                      left: i * den + 3,
                      top: 0,
                      child: Text(
                        AppDateFormat.dayMonth(zacatek.add(Duration(days: i))),
                        style: AppTextStyles.metaSmall.copyWith(
                          fontSize: 10.5,
                          color: palette.muted,
                        ),
                      ),
                    ),
                ],
                for (final (i, a) in naOse.indexed)
                  _Pruh(
                    akce: a,
                    dnes: dnes,
                    vlevo: x(a.od).clamp(0, sirka),
                    vpravo: (x(a.do_) + den).clamp(0, sirka),
                    nahore: 22 + i * _vyskaRadku,
                    useknutyZleva: a.od.isBefore(zacatek),
                    useknutyZprava: a.do_.isAfter(konec),
                  ),
                // Dnešek přes všechny řádky.
                Positioned(
                  left: x(dnes) + den / 2 - 1,
                  top: 14,
                  bottom: 0,
                  child: Container(width: 2, color: AppColors.danger),
                ),
                Positioned(
                  left: x(dnes) + den / 2 - 14,
                  top: 0,
                  child: Text(
                    'dnes',
                    style: AppTextStyles.metaSmall.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Pruh extends StatelessWidget {
  const _Pruh({
    required this.akce,
    required this.dnes,
    required this.vlevo,
    required this.vpravo,
    required this.nahore,
    required this.useknutyZleva,
    required this.useknutyZprava,
  });

  final MarketingovaAkce akce;
  final DateTime dnes;
  final double vlevo;
  final double vpravo;
  final double nahore;
  final bool useknutyZleva;
  final bool useknutyZprava;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plati = akce.plati(dnes);
    final (_, brzy) = stavAkce(akce, dnes);
    final barva = !plati
        ? AppColors.accent.withValues(alpha: 0.28)
        : brzy
        ? const Color(0xFFE8A93A)
        : AppColors.accent;
    const r = Radius.circular(6);

    return Positioned(
      left: vlevo,
      top: nahore,
      width: (vpravo - vlevo).clamp(4, double.infinity),
      height: _CasovaOsa._vyskaRadku - 6,
      child: Tooltip(
        message: '${akce.nazev}\n${obdobi(akce)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: barva,
            borderRadius: BorderRadius.horizontal(
              left: useknutyZleva ? Radius.zero : r,
              right: useknutyZprava ? Radius.zero : r,
            ),
          ),
          child: Text(
            akce.nazev,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.metaSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: plati ? Colors.white : palette.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _KartaAkce extends StatelessWidget {
  const _KartaAkce({required this.akce, required this.dnes, this.onUpravit});

  final MarketingovaAkce akce;
  final DateTime dnes;

  /// Jen správce akcí.
  final VoidCallback? onUpravit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (stav, brzy) = stavAkce(akce, dnes);
    final plati = akce.plati(dnes);
    final barvaStavu = brzy
        ? (context.isDarkMode
              ? const Color(0xFFE8A93A)
              : const Color(0xFFB8740A))
        : plati
        ? AppColors.readyGreen
        : palette.muted;

    return Container(
      key: Key('akce-${akce.id}'),
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.base,
        Insets.sm,
        Insets.lg,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: Insets.xs),
                  child: Text(
                    akce.nazev,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: palette.text,
                    ),
                  ),
                ),
              ),
              if (onUpravit != null)
                IconButton(
                  key: Key('akce-upravit-${akce.id}'),
                  onPressed: onUpravit,
                  tooltip: 'Upravit akci',
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: palette.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.xxs),
          Wrap(
            spacing: Insets.md,
            runSpacing: Insets.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                obdobi(akce),
                style: AppTextStyles.orderNumber.copyWith(
                  color: palette.muted2,
                ),
              ),
              Text(
                stav,
                style: AppTextStyles.metaSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: barvaStavu,
                ),
              ),
            ],
          ),
          if (akce.text.trim().isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Padding(
              padding: const EdgeInsets.only(right: Insets.sm),
              child: Text(
                akce.text,
                style: AppTextStyles.noteText.copyWith(color: palette.text),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Úzká lišta úplně vpravo na tabletu - akce jsou vidět pořád, i když je
/// otevřená zakázka. Klepnutí vysune panel s akcemi přes detail.
class AkceLista extends ConsumerWidget {
  const AkceLista({super.key, required this.otevreno, required this.onTap});

  static const sirka = 52.0;

  final bool otevreno;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prehled = ref.watch(akceProvider).valueOrNull;
    final pocet = prehled?.platne(ref.watch(dnesProvider)).length ?? 0;
    final barva = otevreno ? AppColors.accent : palette.muted2;

    return Material(
      color: otevreno ? AppColors.accent.withValues(alpha: 0.1) : palette.card,
      child: InkWell(
        key: const Key('akce-lista'),
        onTap: onTap,
        child: Container(
          width: sirka,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: palette.hairline)),
          ),
          child: Column(
            children: [
              const SizedBox(height: Insets.xl),
              Icon(Icons.campaign_outlined, color: barva),
              if (pocet > 0) ...[
                const SizedBox(height: Insets.xs),
                Container(
                  key: const Key('akce-lista-pocet'),
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '$pocet',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.metaSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Insets.base),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'MARKETINGOVÉ AKCE',
                  style: AppTextStyles.overline.copyWith(color: barva),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pruh nad seznamem zakázek na telefonu: kolik akcí právě platí.
/// Klepnutí otevře přehled. Správce ho vidí i bez akcí - jinak by neměl
/// kudy akci přidat.
class AkcePruh extends ConsumerWidget {
  const AkcePruh({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prehled = ref.watch(akceProvider).valueOrNull;
    if (prehled == null) return const SizedBox.shrink();
    final dnes = ref.watch(dnesProvider);
    final platne = prehled.platne(dnes);
    if (platne.isEmpty && !prehled.muzeUpravovat) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.accent.withValues(alpha: 0.1),
      child: InkWell(
        key: const Key('akce-pruh'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xl,
            vertical: Insets.md,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.campaign_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: platne.isEmpty
                            ? 'Marketingové akce'
                            : pocetAkci(platne.length),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (platne.isNotEmpty)
                        TextSpan(text: ' · ${platne.first.nazev}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardBody.copyWith(color: palette.text),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Okno pro novou akci (bez [akce]) nebo úpravu - jen pro správce.
Future<void> upravitAkci(
  BuildContext context,
  WidgetRef ref, {
  MarketingovaAkce? akce,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OknoAkce(
      akce: akce,
      autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
    ),
  );
}

class _OknoAkce extends ConsumerStatefulWidget {
  const _OknoAkce({required this.akce, required this.autor});

  final MarketingovaAkce? akce;
  final String autor;

  @override
  ConsumerState<_OknoAkce> createState() => _OknoAkceState();
}

class _OknoAkceState extends ConsumerState<_OknoAkce> {
  late final _nazev = TextEditingController(text: widget.akce?.nazev ?? '');
  late final _text = TextEditingController(text: widget.akce?.text ?? '');
  late DateTimeRange? _platnost = widget.akce == null
      ? null
      : DateTimeRange(start: widget.akce!.od, end: widget.akce!.do_);
  bool _uklada = false;
  String? _chyba;

  @override
  void dispose() {
    _nazev.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _lzeUlozit =>
      !_uklada && _nazev.text.trim().isNotEmpty && _platnost != null;

  Future<void> _vyberPlatnost() async {
    final dnes = ref.read(dnesProvider);
    final vybrano = await showDateRangePicker(
      context: context,
      firstDate: dnes.subtract(const Duration(days: 365)),
      lastDate: dnes.add(const Duration(days: 730)),
      initialDateRange: _platnost,
      currentDate: dnes,
      helpText: 'Platnost akce',
      saveText: 'Hotovo',
    );
    if (vybrano != null && mounted) {
      setState(() => _platnost = vybrano);
    }
  }

  Future<void> _uloz() async {
    final platnost = _platnost;
    if (!_lzeUlozit || platnost == null) return;
    setState(() {
      _uklada = true;
      _chyba = null;
    });
    final akce = MarketingovaAkce(
      id: widget.akce?.id,
      nazev: _nazev.text.trim(),
      text: _text.text.trim(),
      od: platnost.start,
      do_: platnost.end,
    );
    try {
      await ref.read(akceProvider.notifier).uloz(akce);
      if (mounted) Navigator.of(context).pop();
    } on ServiceOrderException catch (chyba) {
      if (mounted) {
        setState(() {
          _uklada = false;
          _chyba = chyba.message;
        });
      }
    }
  }

  Future<void> _smaz() async {
    final id = widget.akce?.id;
    if (id == null) return;
    final ano = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Smazat akci?'),
        content: Text('Akce „${widget.akce!.nazev}" zmizí všem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            key: const Key('akce-smazat-potvrdit'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (ano != true || !mounted) return;
    try {
      await ref.read(akceProvider.notifier).smaz(id);
      if (mounted) Navigator.of(context).pop();
    } on ServiceOrderException catch (chyba) {
      if (mounted) setState(() => _chyba = chyba.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final platnost = _platnost;

    return OknoZapisu(
      nadpis: widget.akce == null ? 'Nová marketingová akce' : 'Upravit akci',
      kam: 'platí pro všechny pobočky',
      autor: widget.autor,
      potvrdit: 'Uložit',
      potvrditKey: const Key('akce-ulozit'),
      onPotvrdit: _lzeUlozit ? _uloz : null,
      obsah: [
        const PopisekPole('NÁZEV'),
        PoleZapisu(
          poleKey: const Key('akce-nazev'),
          controller: _nazev,
          napoveda: 'Např. Zimní prohlídka -20 % na práci',
          maxDelka: 200,
          autofocus: widget.akce == null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('TEXT'),
        PoleZapisu(
          poleKey: const Key('akce-text'),
          controller: _text,
          napoveda: 'Co akce nabízí, pro koho, za kolik…',
          maxDelka: 4000,
          minLines: 4,
          maxLines: 10,
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('PLATNOST'),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('akce-platnost'),
            onPressed: _vyberPlatnost,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              minimumSize: const Size(0, 48),
              side: BorderSide(color: palette.hairline2, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.button),
              ),
            ),
            icon: const Icon(Icons.date_range_rounded, size: 20),
            label: Text(
              platnost == null
                  ? 'Vybrat od – do'
                  : obdobi(
                      MarketingovaAkce(
                        nazev: '',
                        text: '',
                        od: platnost.start,
                        do_: platnost.end,
                      ),
                    ),
            ),
          ),
        ),
        if (_chyba != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _chyba!,
            key: const Key('akce-chyba'),
            style: AppTextStyles.metaSmall.copyWith(color: AppColors.danger),
          ),
        ],
        if (widget.akce != null) ...[
          const SizedBox(height: Insets.base),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('akce-smazat'),
              onPressed: _uklada ? null : _smaz,
              style: TextButton.styleFrom(
                foregroundColor: context.isDarkMode
                    ? const Color(0xFFFF7A7A)
                    : AppColors.danger,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Smazat akci'),
            ),
          ),
        ],
      ],
    );
  }
}
