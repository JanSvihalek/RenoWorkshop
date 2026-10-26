import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/dezen.dart';

/// Žlutá „doporučeno" - tmavší, ať je text čitelný i na bílé.
const _zluta = Color(0xFFC98200);

/// Barva stavu dezénu: zelená v pořádku, žlutá doporučeno, červená nutné.
Color barvaDezenu(StavDezenu? stav, AppPalette palette) => switch (stav) {
  StavDezenu.ok => AppColors.readyGreen,
  StavDezenu.doporuceno => _zluta,
  StavDezenu.nutne => AppColors.danger,
  null => palette.muted,
};

/// Dezén jako auto shora: kola v rozích, uprostřed vůz. Jen ke čtení -
/// souhrn příjmu a karta vozu.
class SchemaDezenu extends StatelessWidget {
  const SchemaDezenu({super.key, required this.dezen});

  final Dezen dezen;

  @override
  Widget build(BuildContext context) {
    Widget kolo(String nazev, double? mm) => _Kolo(
      nazev: nazev,
      barva: barvaDezenu(
        mm == null ? null : dezen.stavKola(mm),
        context.palette,
      ),
      child: Text(
        mm == null ? '–' : formatMm(mm),
        style: AppTextStyles.cardBody.copyWith(
          fontWeight: FontWeight.w700,
          color: barvaDezenu(
            mm == null ? null : dezen.stavKola(mm),
            context.palette,
          ),
        ),
      ),
    );

    return _Rozlozeni(
      vlevoVpredu: kolo('LP', dezen.lp),
      vpravoVpredu: kolo('PP', dezen.pp),
      vlevoVzadu: kolo('LZ', dezen.lz),
      vpravoVzadu: kolo('PZ', dezen.pz),
    );
  }
}

/// Štítek stavu dezénu - „Zimní · Doporučena výměna".
class StitekDezenu extends StatelessWidget {
  const StitekDezenu({super.key, required this.dezen});

  final Dezen dezen;

  @override
  Widget build(BuildContext context) {
    final stav = dezen.stav;
    final barva = barvaDezenu(stav, context.palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: barva.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: barva.withValues(alpha: 0.5)),
      ),
      child: Text(
        '${dezen.zimni ? 'Zimní' : 'Letní'} · ${stav?.label ?? 'Nezměřeno'}',
        style: AppTextStyles.metaSmall.copyWith(
          color: barva,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Změření dezénu - okno uprostřed obrazovky. Vrací nový dezén, nebo
/// `null` (zrušeno).
Future<Dezen?> zmerDezen(BuildContext context, Dezen? puvodni) =>
    showDialog<Dezen>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(Insets.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          // Při otevřené klávesnici se obsah posouvá, ať je Uložit vidět.
          child: SingleChildScrollView(
            child: _OknoDezenu(puvodni: puvodni ?? const Dezen()),
          ),
        ),
      ),
    );

class _OknoDezenu extends StatefulWidget {
  const _OknoDezenu({required this.puvodni});

  final Dezen puvodni;

  @override
  State<_OknoDezenu> createState() => _OknoDezenuState();
}

class _OknoDezenuState extends State<_OknoDezenu> {
  late bool _zimni = widget.puvodni.zimni;
  late final _pole = {
    for (final (nazev, mm) in widget.puvodni.kola)
      nazev: TextEditingController(text: mm == null ? '' : formatMm(mm)),
  };
  late final _fokus = {for (final nazev in _pole.keys) nazev: FocusNode()};

  @override
  void dispose() {
    for (final c in _pole.values) {
      c.dispose();
    }
    for (final f in _fokus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// mm z pole; nečitelné jako `double.nan`.
  double? _mm(String nazev) {
    try {
      return Dezen.zTextu(_pole[nazev]!.text);
    } on FormatException {
      return double.nan;
    }
  }

  bool get _platne => _pole.keys.every((n) => !(_mm(n)?.isNaN ?? false));

  Dezen get _dezen => Dezen(
    zimni: _zimni,
    lp: _mm('LP'),
    pp: _mm('PP'),
    lz: _mm('LZ'),
    pz: _mm('PZ'),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final nazvy = _pole.keys.toList();

    Widget pole(String nazev) {
      final mm = _mm(nazev);
      final chyba = mm != null && mm.isNaN;
      final barva = chyba
          ? AppColors.danger
          : barvaDezenu(
              mm == null ? null : Dezen(zimni: _zimni).stavKola(mm),
              palette,
            );
      final i = nazvy.indexOf(nazev);
      return _Kolo(
        nazev: nazev,
        barva: barva,
        child: SizedBox(
          width: 64,
          child: TextField(
            key: Key('dezen-${nazev.toLowerCase()}'),
            controller: _pole[nazev],
            focusNode: _fokus[nazev],
            autofocus: i == 0 && widget.puvodni.lp == null,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(4),
            ],
            textInputAction: i < nazvy.length - 1
                ? TextInputAction.next
                : TextInputAction.done,
            onSubmitted: (_) => i < nazvy.length - 1
                ? _fokus[nazvy[i + 1]]!.requestFocus()
                : null,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.cardBody.copyWith(
              fontWeight: FontWeight.w700,
              color: barva,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'mm',
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: barva.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: barva, width: 2),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dezén pneu',
            style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Hloubka dezénu v mm u každého kola. Pod 4 mm žlutá, pod 1,6 mm '
            'červená - u zimních pneu je červená už pod 4 mm.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.lg),
          SegmentedButton<bool>(
            key: const Key('dezen-druh'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Letní'),
                icon: Icon(Icons.wb_sunny_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Zimní'),
                icon: Icon(Icons.ac_unit_rounded),
              ),
            ],
            selected: {_zimni},
            onSelectionChanged: (v) => setState(() => _zimni = v.first),
          ),
          const SizedBox(height: Insets.lg),
          _Rozlozeni(
            vlevoVpredu: pole('LP'),
            vpravoVpredu: pole('PP'),
            vlevoVzadu: pole('LZ'),
            vpravoVzadu: pole('PZ'),
          ),
          const SizedBox(height: Insets.xl),
          // Tlačítka mají v motivu plnou šířku - v řádku každé půlku.
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('dezen-zrusit'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Zrušit'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('dezen-ulozit'),
                  onPressed: _platne
                      ? () => Navigator.of(context).pop(_dezen)
                      : null,
                  child: Text(_platne ? 'Uložit' : 'Nejvýš 20 mm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Auto shora: přední kola nahoře, mezi nimi karoserie.
class _Rozlozeni extends StatelessWidget {
  const _Rozlozeni({
    required this.vlevoVpredu,
    required this.vpravoVpredu,
    required this.vlevoVzadu,
    required this.vpravoVzadu,
  });

  final Widget vlevoVpredu;
  final Widget vpravoVpredu;
  final Widget vlevoVzadu;
  final Widget vpravoVzadu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(children: [vlevoVpredu, const SizedBox(height: 56), vlevoVzadu]),
        const SizedBox(width: Insets.md),
        Container(
          width: 72,
          height: 168,
          decoration: BoxDecoration(
            border: Border.all(color: palette.hairline, width: 2),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
              bottom: Radius.circular(16),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: Insets.sm),
          child: Text(
            'PŘED',
            style: AppTextStyles.overline.copyWith(
              color: palette.muted,
              fontSize: 9,
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Column(
          children: [vpravoVpredu, const SizedBox(height: 56), vpravoVzadu],
        ),
      ],
    );
  }
}

/// Kolo - popisek (LP…) a hodnota nebo pole.
class _Kolo extends StatelessWidget {
  const _Kolo({required this.nazev, required this.barva, required this.child});

  final String nazev;
  final Color barva;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nazev,
          style: AppTextStyles.overline.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 36),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: barva.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          child: child,
        ),
      ],
    );
  }
}
