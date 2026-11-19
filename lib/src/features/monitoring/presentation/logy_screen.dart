import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/akce_providers.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../domain/logy.dart';
import '../domain/monitoring.dart' show popisKlienta;
import 'monitoring_providers.dart';

/// Kolik řádků se načte najednou; další přinese „Načíst další“.
const _stranka = 100;

/// Admin › Logy - jednotlivé řádky logu přístupů a událostí s filtrem,
/// řazením a stránkováním. Stejné jako Admin › Logy na webu. Klepnutím
/// na řádek se rozbalí všechno, co v logu je.
class LogyScreen extends ConsumerStatefulWidget {
  const LogyScreen({super.key});

  @override
  ConsumerState<LogyScreen> createState() => _LogyScreenState();
}

class _LogyScreenState extends ConsumerState<LogyScreen> {
  DruhLogu _druh = DruhLogu.pristupy;
  late FiltrLogu _filtr = FiltrLogu.vychozi(ref.read(dnesProvider));
  String _razeni = 'cas';
  bool _vzestupne = false;

  final List<ZaznamLogu> _polozky = [];
  int _celkem = 0;
  bool _nacita = true;
  String? _chyba;
  final Set<String> _rozbalene = {};

  /// Číslo dotazu - odpověď na starší (jiný filtr) se zahodí.
  int _dotaz = 0;

  @override
  void initState() {
    super.initState();
    // setState v initState nejde - první stránka až po prvním snímku.
    WidgetsBinding.instance.addPostFrameCallback((_) => _nacti(znovu: true));
  }

  Future<void> _nacti({required bool znovu}) async {
    final cislo = ++_dotaz;
    setState(() {
      _nacita = true;
      _chyba = null;
      if (znovu) {
        _polozky.clear();
        _rozbalene.clear();
      }
    });
    try {
      final stranka = await ref
          .read(logyDataSourceProvider)
          .nactiLog(
            _druh,
            _filtr.dotaz(
              _druh,
              razeni: _razeni,
              vzestupne: _vzestupne,
              offset: znovu ? 0 : _polozky.length,
              limit: _stranka,
            ),
          );
      if (!mounted || cislo != _dotaz) return;
      setState(() {
        _polozky.addAll(stranka.polozky);
        _celkem = stranka.celkem;
        _nacita = false;
      });
    } on Object catch (chyba) {
      if (!mounted || cislo != _dotaz) return;
      setState(() {
        _nacita = false;
        _chyba = chyba is ServiceOrderException
            ? chyba.message
            : 'Log se nepodařilo načíst.';
      });
    }
  }

  void _zmen(VoidCallback zmena) {
    setState(zmena);
    _nacti(znovu: true);
  }

  Future<void> _vyberObdobi() async {
    final dnes = ref.read(dnesProvider);
    final vybrano = await showDateRangePicker(
      context: context,
      firstDate: dnes.subtract(const Duration(days: 91)),
      lastDate: dnes,
      initialDateRange: DateTimeRange(start: _filtr.od, end: _filtr.do_),
      currentDate: dnes,
      helpText: 'Období logu',
      saveText: 'Hotovo',
    );
    if (vybrano != null && mounted) {
      _zmen(
        () => _filtr = _filtr.copyWith(od: vybrano.start, do_: vybrano.end),
      );
    }
  }

  Future<void> _otevriFiltr() async {
    final novy = await showModalBottomSheet<FiltrLogu>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OknoFiltru(druh: _druh, filtr: _filtr),
    );
    if (novy != null && mounted) _zmen(() => _filtr = novy);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pocetFiltru = _filtr.pocet(_druh);
    final sloupce = _druh == DruhLogu.pristupy
        ? razeniPristupu
        : razeniUdalosti;
    final popisRazeni = sloupce
        .firstWhere((s) => s.$1 == _razeni, orElse: () => sloupce.first)
        .$2;
    final male = AppTextStyles.metaSmall.copyWith(color: palette.muted);

    return ColoredBox(
      color: palette.background,
      child: RefreshIndicator.adaptive(
        onRefresh: () => _nacti(znovu: true),
        child: ListView.builder(
          key: const Key('logy'),
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.base,
            Insets.lg,
            Insets.giant,
          ),
          itemCount: _polozky.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<DruhLogu>(
                    key: const Key('logy-druh'),
                    showSelectedIcon: false,
                    segments: [
                      for (final d in DruhLogu.values)
                        ButtonSegment(value: d, label: Text(d.popis)),
                    ],
                    selected: {_druh},
                    onSelectionChanged: (v) => _zmen(() {
                      _druh = v.first;
                      _razeni = 'cas';
                      _vzestupne = false;
                    }),
                  ),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        key: const Key('logy-obdobi'),
                        avatar: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          '${AppDateFormat.dayMonth(_filtr.od)} – '
                          '${AppDateFormat.dayMonth(_filtr.do_)}',
                        ),
                        onPressed: _vyberObdobi,
                      ),
                      ActionChip(
                        key: const Key('logy-filtr'),
                        avatar: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: pocetFiltru > 0 ? AppColors.accent : null,
                        ),
                        label: Text(
                          pocetFiltru > 0 ? 'Filtr ($pocetFiltru)' : 'Filtr',
                        ),
                        onPressed: _otevriFiltr,
                      ),
                      if (_druh == DruhLogu.pristupy)
                        FilterChip(
                          key: const Key('logy-jen-akce'),
                          label: const Text('Jen akce uživatele'),
                          tooltip:
                              'Bez fotek a dokumentů, které se načtou s detailem, '
                              'a bez obnovy seznamu. Chyby jsou vidět vždy.',
                          selected: _filtr.jenAkce,
                          onSelected: (v) =>
                              _zmen(() => _filtr = _filtr.copyWith(jenAkce: v)),
                        ),
                      if (pocetFiltru > 0)
                        ActionChip(
                          key: const Key('logy-zrusit-filtr'),
                          avatar: const Icon(Icons.close, size: 18),
                          label: const Text('Zrušit filtr'),
                          onPressed: () =>
                              _zmen(() => _filtr = _filtr.bezFiltru()),
                        ),
                      PopupMenuButton<String>(
                        key: const Key('logy-razeni'),
                        tooltip: 'Řadit',
                        onSelected: (s) => _zmen(() {
                          if (s == _razeni) {
                            _vzestupne = !_vzestupne;
                          } else {
                            _razeni = s;
                            _vzestupne = s == 'email';
                          }
                        }),
                        itemBuilder: (_) => [
                          for (final (kod, popis) in sloupce)
                            CheckedPopupMenuItem(
                              value: kod,
                              checked: kod == _razeni,
                              child: Text(popis),
                            ),
                        ],
                        child: Chip(
                          avatar: Icon(
                            _vzestupne
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 18,
                          ),
                          label: Text(popisRazeni),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    _polozky.isEmpty && !_nacita && _chyba == null
                        ? 'Filtru nic neodpovídá.'
                        : '${_cislo(_polozky.length)} z ${_cislo(_celkem)} záznamů',
                    key: const Key('logy-pocet'),
                    style: male,
                  ),
                  const SizedBox(height: Insets.xs),
                ],
              );
            }
            if (i == _polozky.length + 1) {
              if (_chyba != null) {
                return Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Column(
                    children: [
                      Text(_chyba!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () => _nacti(znovu: _polozky.isEmpty),
                        child: const Text('Zkusit znovu'),
                      ),
                    ],
                  ),
                );
              }
              if (_nacita) {
                return const Padding(
                  padding: EdgeInsets.all(Insets.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_polozky.length < _celkem) {
                return Padding(
                  padding: const EdgeInsets.only(top: Insets.base),
                  child: OutlinedButton(
                    key: const Key('logy-dalsi'),
                    onPressed: () => _nacti(znovu: false),
                    child: Text(
                      'Načíst další (zbývá ${_cislo(_celkem - _polozky.length)})',
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final z = _polozky[i - 1];
            return _RadekLogu(
              z,
              rozbaleny: _rozbalene.contains(z.id),
              onKlepnuti: () => setState(() {
                if (!_rozbalene.remove(z.id)) _rozbalene.add(z.id);
              }),
              onUzivatel: z.email == null
                  ? null
                  : () => _zmen(() => _filtr = _filtr.copyWith(email: z.email)),
              onZakazka: z.zakazka == null
                  ? null
                  : () => context.push(AppRoutes.orderDetail(z.zakazka!)),
            );
          },
        ),
      ),
    );
  }
}

String _cislo(int n) => NumberFormat.decimalPattern('cs_CZ').format(n);

class _RadekLogu extends StatelessWidget {
  const _RadekLogu(
    this.z, {
    required this.rozbaleny,
    required this.onKlepnuti,
    this.onUzivatel,
    this.onZakazka,
  });

  final ZaznamLogu z;
  final bool rozbaleny;
  final VoidCallback onKlepnuti;
  final VoidCallback? onUzivatel;
  final VoidCallback? onZakazka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final male = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    final stav = z.stav;
    final barvaStavu = stav == null
        ? null
        : stav >= 500
        ? AppColors.danger
        : stav == 401
        ? palette.muted
        : stav >= 400
        ? const Color(0xFFB8740A)
        : const Color(0xFF2E9E5B);
    final typ = switch (z.typ) {
      'chyba' => 'Chyba',
      'audit' => 'Audit',
      'udalost' => 'Událost',
      _ => null,
    };

    return InkWell(
      key: Key('log-${z.id}'),
      onTap: onKlepnuti,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        color: rozbaleny ? AppColors.accent.withValues(alpha: 0.08) : null,
        foregroundDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Na úzkém telefonu se čas, jméno a štítek zalomí.
                Expanded(
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        z.kdy == null ? '—' : AppDateFormat.dateTime(z.kdy!),
                        style: male,
                      ),
                      GestureDetector(
                        onTap: onUzivatel,
                        child: Text(
                          z.jmeno ?? z.email ?? 'nepřihlášený',
                          style: male.copyWith(
                            color: palette.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _Stitek(popisKlienta(z.klient)),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                if (stav != null) ...[
                  Text(
                    '$stav',
                    style: male.copyWith(
                      color: barvaStavu,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '${_cislo(z.ms ?? 0)} ms',
                    style: male.copyWith(
                      color: (z.ms ?? 0) >= 3000 ? AppColors.danger : null,
                    ),
                  ),
                ] else if (typ != null)
                  Text(
                    typ,
                    style: male.copyWith(
                      color: z.typ == 'chyba'
                          ? AppColors.danger
                          : z.typ == 'audit'
                          ? const Color(0xFFB8740A)
                          : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                text: z.popis,
                children: [
                  if (z.zakazka != null)
                    TextSpan(
                      text: '  ${z.zakazka}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              style: AppTextStyles.cardBody.copyWith(
                color: z.jeChyba
                    ? AppColors.danger
                    : z.zapis
                    ? AppColors.repairBlue
                    : z.auto
                    ? palette.muted
                    : palette.text,
                fontWeight: z.zapis || z.jeChyba ? FontWeight.w600 : null,
              ),
            ),
            if (z.podpopis != null) Text(z.podpopis!, style: male),
            if (!rozbaleny && z.chyba != null)
              Text(
                z.chyba!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: male.copyWith(color: palette.muted2),
              ),
            if (rozbaleny) ...[
              const SizedBox(height: Insets.sm),
              for (final (k, v) in z.detaily)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          k,
                          style: male.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          v,
                          style: male.copyWith(color: palette.text),
                        ),
                      ),
                    ],
                  ),
                ),
              if (onZakazka != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onZakazka,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text('Otevřít zakázku ${z.zakazka}'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stitek extends StatelessWidget {
  const _Stitek(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tmava = context.isDarkMode;
    final (pozadi, barva) = switch (text) {
      'Web' =>
        tmava
            ? (const Color(0x295FD38D), const Color(0xFF5FD38D))
            : (const Color(0xFFE3F5EA), const Color(0xFF1B6E3C)),
      'Plánovač' =>
        tmava
            ? (const Color(0x29E8A93A), const Color(0xFFE8A93A))
            : (const Color(0xFFFFF1D6), const Color(0xFF8A5A00)),
      _ =>
        tmava
            ? (const Color(0x294599FE), const Color(0xFF8CC0FF))
            : (const Color(0xFFEAF2FC), const Color(0xFF1F4F8F)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: pozadi,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.metaSmall.copyWith(
          color: barva,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Filtr logu v okně zespodu - jen pole, která daný log zná.
class _OknoFiltru extends ConsumerStatefulWidget {
  const _OknoFiltru({required this.druh, required this.filtr});

  final DruhLogu druh;
  final FiltrLogu filtr;

  @override
  ConsumerState<_OknoFiltru> createState() => _OknoFiltruState();
}

class _OknoFiltruState extends ConsumerState<_OknoFiltru> {
  late FiltrLogu _f = widget.filtr;
  late final _cesta = TextEditingController(text: widget.filtr.cesta);
  late final _zakazka = TextEditingController(text: widget.filtr.zakazka);
  late final _hledat = TextEditingController(text: widget.filtr.hledat);

  @override
  void dispose() {
    _cesta.dispose();
    _zakazka.dispose();
    _hledat.dispose();
    super.dispose();
  }

  FiltrLogu get _vysledek => _f.copyWith(
    cesta: _cesta.text,
    zakazka: _zakazka.text,
    hledat: _hledat.text,
  );

  Widget _vyber(
    String popisek,
    String hodnota,
    List<(String, String)> volby,
    ValueChanged<String> onZmena, {
    Key? key,
  }) {
    final platna = volby.any((v) => v.$1 == hodnota) ? hodnota : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.base),
      child: DropdownButtonFormField<String>(
        key: key,
        initialValue: platna,
        isExpanded: true,
        decoration: InputDecoration(labelText: popisek),
        items: [
          for (final (kod, text) in volby)
            DropdownMenuItem(value: kod, child: Text(text)),
        ],
        onChanged: (v) => onZmena(v ?? ''),
      ),
    );
  }

  Widget _pole(String popisek, TextEditingController c, {String? napoveda}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Insets.base),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: popisek, hintText: napoveda),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final volby = ref.watch(volbyLoguProvider).valueOrNull ?? const VolbyLogu();
    final pristupy = widget.druh == DruhLogu.pristupy;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.xl,
        0,
        Insets.xl,
        Insets.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtr – ${widget.druh.popis.toLowerCase()}',
              style: AppTextStyles.sectionTitle.copyWith(
                color: context.palette.text,
              ),
            ),
            const SizedBox(height: Insets.base),
            _vyber(
              'Uživatel',
              _f.email,
              [
                ('', 'Všichni'),
                for (final u in volby.uzivatele)
                  (
                    u.email,
                    u.jmeno == null ? u.email : '${u.jmeno} (${u.email})',
                  ),
              ],
              (v) => setState(() => _f = _f.copyWith(email: v)),
              key: const Key('logy-filtr-uzivatel'),
            ),
            _vyber('Odkud', _f.klient, const [
              ('', 'Všude'),
              ('aplikace', 'Aplikace'),
              ('web', 'Web'),
              ('plan', 'Plánovač'),
            ], (v) => setState(() => _f = _f.copyWith(klient: v))),
            if (pristupy) ...[
              _vyber('Metoda', _f.metoda, const [
                ('', 'Všechny'),
                ('GET', 'GET – čtení'),
                ('POST', 'POST'),
                ('PUT', 'PUT'),
                ('PATCH', 'PATCH'),
                ('DELETE', 'DELETE'),
              ], (v) => setState(() => _f = _f.copyWith(metoda: v))),
              _vyber(
                'Výsledek',
                _f.vysledek,
                const [
                  ('', 'Vše'),
                  ('ok', 'V pořádku'),
                  ('chyby', 'Chyby (bez 401)'),
                  ('4xx', 'Odmítnuté 4xx'),
                  ('5xx', 'Chyby služby 5xx'),
                  ('401', 'Vypršené přihlášení 401'),
                ],
                (v) => setState(() => _f = _f.copyWith(vysledek: v)),
                key: const Key('logy-filtr-vysledek'),
              ),
              _vyber('Doba', _f.minMs, const [
                ('', 'Jakákoli'),
                ('500', 'nad 0,5 s'),
                ('1000', 'nad 1 s'),
                ('3000', 'nad 3 s'),
                ('10000', 'nad 10 s'),
              ], (v) => setState(() => _f = _f.copyWith(minMs: v))),
              _pole('Cesta obsahuje', _cesta, napoveda: 'stavy, photos…'),
            ] else ...[
              _vyber('Typ', _f.typ, const [
                ('', 'Vše'),
                ('udalost', 'Události'),
                ('chyba', 'Chyby'),
                ('audit', 'Audit'),
              ], (v) => setState(() => _f = _f.copyWith(typ: v))),
              _vyber('Název', _f.nazev, [
                ('', 'Všechny'),
                for (final n in volby.udalosti) (n, n),
              ], (v) => setState(() => _f = _f.copyWith(nazev: v))),
              _pole('Hledat', _hledat, napoveda: 'obrazovka, detail, chyba…'),
            ],
            _pole('Zakázka', _zakazka, napoveda: 'číslo zakázky'),
            const SizedBox(height: Insets.sm),
            // Tlačítka mají v motivu plnou šířku - půl na půl.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(widget.filtr.bezFiltru()),
                    child: const Text('Zrušit filtr'),
                  ),
                ),
                const SizedBox(width: Insets.base),
                Expanded(
                  child: FilledButton(
                    key: const Key('logy-filtr-pouzit'),
                    onPressed: () => Navigator.of(context).pop(_vysledek),
                    child: const Text('Použít'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
