import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import 'plan_karta.dart' show obdobiPlanu;
import '../../akce/presentation/akce_providers.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/entities/service_order.dart';
import '../../orders/presentation/controllers/order_actions_controller.dart';
import '../../orders/presentation/widgets/okno_zapisu.dart';
import '../../orders/presentation/widgets/pridat_stav_sheet.dart';
import '../domain/kapacita.dart';
import '../domain/prehled_planu.dart';
import 'plan_providers.dart';

/// Okno úkonu zakázky na klempírně/lakovně - z detailu zakázky i z plánovače.
/// Bez [ukon] se přidává nový. [plan] je celý plán zakázky: kód laku je
/// společný a nový úkon z něj bere výchozí typ a den.
Future<void> naplanovatKlempirnu(
  BuildContext context,
  WidgetRef ref, {
  required String zakazkaId,
  String? spz,
  PlanKlempirny? plan,
  UkonPlanu? ukon,

  /// Barva vozu z Heliosu - předvyplní kód laku.
  BarvaVozu? barva,

  /// Den, na který se klepnulo v plánu - nový úkon ho má předvyplněný.
  DateTime? den,

  /// Zakázka úkonu - z jejích stavů je vidět průběh, jde zahájit a dokončit.
  ServiceOrder? zakazka,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OknoPlanu(
      zakazkaId: zakazkaId,
      spz: spz,
      plan: plan,
      ukon: ukon,
      barva: barva,
      den: den,
      zakazka: zakazka,
      onZahajit: zakazka == null
          ? null
          : (typ) => pridatStavZakazce(context, ref, zakazka, ukon: typ),
      autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
    ),
  );
}

class _OknoPlanu extends ConsumerStatefulWidget {
  const _OknoPlanu({
    required this.zakazkaId,
    required this.spz,
    required this.plan,
    required this.ukon,
    required this.barva,
    required this.den,
    required this.zakazka,
    required this.onZahajit,
    required this.autor,
  });

  final String zakazkaId;
  final String? spz;
  final PlanKlempirny? plan;
  final UkonPlanu? ukon;
  final BarvaVozu? barva;
  final DateTime? den;
  final ServiceOrder? zakazka;
  final void Function(TypUkonu typ)? onZahajit;
  final String autor;

  @override
  ConsumerState<_OknoPlanu> createState() => _OknoPlanuState();
}

class _OknoPlanuState extends ConsumerState<_OknoPlanu> {
  late DateTimeRange? _obdobi = _vychoziObdobi();
  late final _kod = TextEditingController(
    text: widget.plan?.kodLaku ?? widget.barva?.kod ?? '',
  );
  late final _poznamka = TextEditingController(
    text: widget.ukon?.poznamka ?? '',
  );
  late String? _vybranyTyp = widget.ukon?.typ.kod;
  // Dílna se řídí úkonem, dokud ji někdo nevybere ručně.
  late Dilna? _vybranaDilna = widget.ukon?.dilna;
  JednotkaKapacity _jednotka = JednotkaKapacity.hodiny;
  late final _delka = TextEditingController(
    text: switch (widget.ukon?.aw) {
      final aw? => hodnotaKapacity(aw, _jednotka),
      null => '',
    },
  );
  bool _uklada = false;
  String? _chyba;

  @override
  void dispose() {
    _kod.dispose();
    _poznamka.dispose();
    _delka.dispose();
    super.dispose();
  }

  /// Úkon má svoje dny, klepnutí v plánu den vybralo, u detailu zakázky
  /// navazuje další úkon na konec plánu.
  DateTimeRange? _vychoziObdobi() {
    if (widget.ukon case final u?) {
      return DateTimeRange(start: u.od, end: u.do_);
    }
    final den =
        widget.den ??
        (widget.plan == null ? null : navazujiciDen(widget.plan!));
    return den == null ? null : DateTimeRange(start: den, end: den);
  }

  /// Vybraný typ, jinak výchozí pro nový úkon. `null`, dokud se typy načítají.
  String? _typ(List<TypUkonu> typy) =>
      _vybranyTyp ?? vychoziTypUkonu(typy, widget.plan)?.kod;

  /// Zadaná délka v AW; `null` = prázdné nebo neplatné.
  int? get _pocetAw {
    final aw = prevedNaAw(_delka.text, _jednotka);
    return aw != null && aw >= 1 ? aw : null;
  }

  /// Zadaná délka se převede, aby se číslo nepřečetlo v jiné jednotce.
  void _zmenJednotku(JednotkaKapacity nova) {
    final aw = _pocetAw;
    setState(() {
      _jednotka = nova;
      _delka.text = aw == null ? '' : hodnotaKapacity(aw, nova);
    });
  }

  Future<void> _vyberObdobi() async {
    final dnes = ref.read(dnesProvider);
    final vybrano = await showDateRangePicker(
      context: context,
      firstDate: dnes.subtract(const Duration(days: 365)),
      lastDate: dnes.add(const Duration(days: 365)),
      initialDateRange: _obdobi,
      currentDate: dnes,
      helpText: 'Úkon od – do',
      // Ne „Hotovo" - tak se v okně jmenuje stav plánu.
      saveText: 'Použít',
    );
    if (vybrano != null && mounted) setState(() => _obdobi = vybrano);
  }

  /// Uloží nebo smaže úkon; chyba zůstane v okně.
  Future<void> _proved(Future<String?> Function() akce) async {
    setState(() {
      _uklada = true;
      _chyba = null;
    });
    final chyba = await akce();
    if (!mounted) return;
    if (chyba == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _uklada = false;
        _chyba = chyba;
      });
    }
  }

  Future<void> _uloz(String typ) async {
    final obdobi = _obdobi;
    if (_uklada || obdobi == null) return;
    final kod = _kod.text.trim().toUpperCase();
    await _proved(
      () => ref
          .read(orderActionsProvider.notifier)
          .ulozUkonPlanu(
            widget.zakazkaId,
            VstupUkonu(
              typKod: typ,
              od: obdobi.start,
              do_: obdobi.end,
              kodLaku: kod.isEmpty ? null : kod,
              poznamka: _poznamka.text.trim(),
              // Hotovo dělá jen Dokončit (jako v průběhu) - uložení
              // stav úkonu nemění.
              hotovo: widget.ukon?.hotovo ?? false,
              dilna: _vybranaDilna ?? Dilna.vychoziProTyp(typ),
              aw: _pocetAw,
            ),
            ukonId: widget.ukon?.id,
          ),
    );
  }

  Future<void> _dokonci(String zaznamId) => _proved(() async {
    final hotovo = await ref
        .read(orderActionsProvider.notifier)
        .dokonciStav(widget.zakazkaId, zaznamId);
    return hotovo ? null : 'Krok se nepodařilo dokončit.';
  });

  /// Průběh otevřeného úkonu: co s ním je. Tlačítka (Zahájit, Dokončit)
  /// jsou dole u ostatních - [_akcePrubehu].
  Widget _prubeh(PolozkaOsy polozka) {
    final palette = context.palette;
    return Container(
      key: const Key('plan-okno-prubeh'),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      margin: const EdgeInsets.only(bottom: Insets.base),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: palette.hairline),
      ),
      child: Text(
        switch (polozka.stav) {
          StavPolozky.ceka => 'Čeká',
          StavPolozky.dalsi => 'Další na řadě',
          StavPolozky.probiha => 'Probíhá',
          StavPolozky.hotovo => 'Dokončeno',
          StavPolozky.zruseno => 'Zrušeno',
        },
        style: AppTextStyles.cardBody.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Zahájit a Dokončit jako v průběhu zakázky - dole u ostatních tlačítek.
  List<Widget> _akcePrubehu(UkonPlanu ukon, PolozkaOsy polozka) {
    final zaznamId = polozka.zaznam?.id;
    return [
      if (polozka.stav == StavPolozky.ceka || polozka.stav == StavPolozky.dalsi)
        OutlinedButton(
          key: const Key('plan-okno-zahajit'),
          onPressed: _uklada
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onZahajit?.call(ukon.typ);
                },
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Zahájit'),
        ),
      if (polozka.stav == StavPolozky.probiha && zaznamId != null)
        OutlinedButton(
          key: const Key('plan-okno-dokoncit'),
          onPressed: _uklada ? null : () => _dokonci(zaznamId),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Dokončit'),
        ),
    ];
  }

  /// Úkon se nemaže, zruší se - zůstane v průběhu zakázky se štítkem
  /// Zrušeno. Ptá se, ať se to nestane omylem; vrátit to nejde.
  Future<void> _zrus(UkonPlanu ukon) async {
    final posledni = (widget.plan?.ukony.length ?? 0) <= 1;
    final ano = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Opravdu zrušit úkon?'),
        content: Text(
          '„${ukon.typ.nazev}" zmizí z plánovače a nebude se počítat do '
          'vytížení. V průběhu zakázky zůstane se štítkem Zrušeno. Zrušení '
          'nejde vrátit.'
          '${posledni ? ' Je to poslední úkon - zakázka zůstane v plánovači mezi zakázkami bez plánu.' : ''}',
        ),
        actions: [
          TextButton(
            key: const Key('plan-zrusit-ne'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ponechat'),
          ),
          TextButton(
            key: const Key('plan-zrusit-potvrdit'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Zrušit úkon'),
          ),
        ],
      ),
    );
    if (ano != true || !mounted) return;
    await _proved(
      () => ref
          .read(orderActionsProvider.notifier)
          .zrusUkonPlanu(widget.zakazkaId, ukon.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final obdobi = _obdobi;
    final nacitani = ref.watch(typyUkonuProvider);
    final nabidka = nacitani.valueOrNull ?? const <TypUkonu>[];
    final ukon = widget.ukon;
    final stavajici = ukon?.typ;
    // Vyřazený typ v nabídce není, starému úkonu ale zůstává.
    final typy = [
      ...nabidka,
      if (stavajici != null && !nabidka.any((n) => n.kod == stavajici.kod))
        stavajici,
    ];
    final typ = _typ(nabidka);
    final cervena = context.isDarkMode
        ? const Color(0xFFFF7A7A)
        : AppColors.danger;
    final zakazka = widget.zakazka;
    final prubeh = ukon == null || zakazka == null
        ? null
        : osaPrubehu(
            widget.plan,
            zakazka.historieStavu,
          ).where((p) => p.ukon?.id == ukon.id).firstOrNull;

    return OknoZapisu(
      nadpis: ukon != null
          ? 'Upravit úkon'
          : widget.plan != null
          ? 'Přidat úkon'
          : 'Zaplánovat na klempírnu/lakovnu',
      kam: 'klempírna / lakovna',
      spz: widget.spz,
      cisloZakazky: widget.zakazkaId,
      autor: widget.autor,
      potvrdit: ukon != null
          ? 'Uložit'
          : widget.plan != null
          ? 'Přidat'
          : 'Zaplánovat',
      potvrditKey: const Key('plan-ulozit'),
      onPotvrdit: !_uklada && obdobi != null && typ != null && _pocetAw != null
          ? () => _uloz(typ)
          : null,
      // Všechna tlačítka dole: Zrušit úkon vlevo, Zahájit/Dokončit vpravo.
      akceVlevo: ukon == null
          ? null
          : TextButton.icon(
              key: const Key('plan-zrusit'),
              onPressed: _uklada ? null : () => _zrus(ukon),
              style: TextButton.styleFrom(foregroundColor: cervena),
              icon: const Icon(Icons.event_busy_outlined, size: 20),
              label: const Text('Zrušit úkon'),
            ),
      dalsiAkce: ukon != null && prubeh != null
          ? _akcePrubehu(ukon, prubeh)
          : const [],
      obsah: [
        if (prubeh != null) _prubeh(prubeh),
        const PopisekPole('ÚKON'),
        // Pole si pamatuje jen první hodnotu - proto až s načtenými typy.
        if (typ == null)
          DropdownButtonFormField<String>(
            key: const Key('plan-typ-nacita'),
            isExpanded: true,
            hint: const Text('Načítám…'),
            items: const [],
            onChanged: null,
          )
        else
          DropdownButtonFormField<String>(
            key: const Key('plan-typ'),
            initialValue: typ,
            isExpanded: true,
            items: [
              for (final t in typy)
                DropdownMenuItem(value: t.kod, child: Text(t.nazev)),
            ],
            onChanged: (v) => setState(() => _vybranyTyp = v),
          ),
        if (nacitani.hasError && typ == null) ...[
          const SizedBox(height: Insets.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Typy úkonů se nepodařilo načíst.',
                  style: AppTextStyles.metaSmall.copyWith(color: cervena),
                ),
              ),
              TextButton(
                key: const Key('plan-typy-znovu'),
                onPressed: () => ref.invalidate(typyUkonuProvider),
                child: const Text('Zkusit znovu'),
              ),
            ],
          ),
        ],
        const SizedBox(height: Insets.base),
        const PopisekPole('TYP'),
        // Klíč podle úkonu: dokud dílnu nikdo nevybral, jde s úkonem.
        DropdownButtonFormField<Dilna>(
          key: ValueKey('plan-dilna-${_vybranaDilna ?? typ}'),
          initialValue: _vybranaDilna ?? Dilna.vychoziProTyp(typ),
          isExpanded: true,
          items: [
            for (final d in Dilna.values)
              DropdownMenuItem(value: d, child: Text(d.nazev)),
          ],
          onChanged: (v) => setState(() => _vybranaDilna = v),
        ),
        const SizedBox(height: Insets.base),
        PopisekPole(_jednotka == JednotkaKapacity.hodiny ? 'HODINY' : 'AW'),
        PoleZapisu(
          poleKey: const Key('plan-aw'),
          controller: _delka,
          napoveda: _jednotka == JednotkaKapacity.hodiny
              ? 'Např. 4'
              : 'Např. 48',
          maxDelka: 7,
          klavesnice: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Insets.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<JednotkaKapacity>(
            key: const Key('plan-jednotka'),
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
            onSelectionChanged: (v) => _zmenJednotku(v.first),
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          switch (_pocetAw) {
            final aw? => '$aw AW = ${hodinyText(aw / awZaHodinu)} h práce',
            null => '1 h = 12 AW, 1 AW = 5 minut práce.',
          },
          key: const Key('plan-aw-hodiny'),
          style: AppTextStyles.meta.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('OD – DO'),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('plan-obdobi'),
            onPressed: _vyberObdobi,
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
              obdobi == null
                  ? 'Vybrat dny'
                  : obdobiPlanu(obdobi.start, obdobi.end),
            ),
          ),
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('KÓD LAKU'),
        PoleZapisu(
          poleKey: const Key('plan-kod-laku'),
          controller: _kod,
          napoveda: 'Např. 416, C4P',
          maxDelka: 20,
        ),
        const SizedBox(height: Insets.xs),
        Text(
          'Společný pro celou zakázku.',
          style: AppTextStyles.meta.copyWith(color: context.palette.muted),
        ),
        if (widget.barva case final barva?)
          Text(
            'Z Heliosu: ${barva.popis}',
            key: const Key('plan-barva-z-heliosu'),
            style: AppTextStyles.meta.copyWith(color: context.palette.muted),
          ),
        const SizedBox(height: Insets.base),
        const PopisekPole('POZNÁMKA'),
        PoleZapisu(
          poleKey: const Key('plan-poznamka'),
          controller: _poznamka,
          napoveda: 'Co se bude dělat - díly, strany vozu…',
          maxDelka: 1000,
          minLines: 2,
          maxLines: 6,
        ),
        if (_chyba != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _chyba!,
            key: const Key('plan-chyba'),
            style: AppTextStyles.metaSmall.copyWith(color: cervena),
          ),
        ],
      ],
    );
  }
}
