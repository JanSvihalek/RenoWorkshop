import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../domain/uzivatele.dart';
import 'uzivatele_providers.dart';

/// Poslední uložení do stavového řádku („Uloženo · Lang Jaroslav · BMW BSL
/// → zápis"), nebo chyba. `null` = výchozí text.
final stavUlozeniUzivateluProvider =
    StateProvider<({String text, bool chyba})?>((ref) => null);

/// Od jaké šířky obsahu je seznam a detail vedle sebe (tablet, PC).
const _sirkaVedleSebe = 840.0;

/// Uživatelé a práva (záložka Admin, jen admin). Stejné jako stránka
/// Uživatelé a práva na webu: vlevo seznam s hledáním, filtry a shrnutím
/// práv, vpravo detail vybraného. Na telefonu seznam a klepnutím detail.
class UzivateleScreen extends ConsumerStatefulWidget {
  const UzivateleScreen({super.key, this.jakoZalozka = false});

  /// Záložka Admin v hlavní navigaci - bez šipky zpět. Jinak samostatná
  /// obrazovka (z plánovače).
  final bool jakoZalozka;

  @override
  ConsumerState<UzivateleScreen> createState() => _UzivateleScreenState();
}

class _UzivateleScreenState extends ConsumerState<UzivateleScreen> {
  String _hledani = '';
  FiltrUzivatelu _filtr = FiltrUzivatelu.vse;

  /// Vybraný e-mail - zůstává, i když ho filtr schová.
  String? _vybrany;

  Future<void> _pridat(String email, {required bool vedleSebe}) async {
    final novy = UzivatelSpravy(email: email);
    setState(() => _vybrany = email);
    try {
      await ulozUzivatele(ref, novy);
      if (!mounted) return;
      ref.read(stavUlozeniUzivateluProvider.notifier).state = (
        text: 'Uloženo · $email · přidán',
        chyba: false,
      );
      if (!vedleSebe && mounted) await _otevri(email);
    } on ServiceOrderException catch (chyba) {
      if (!mounted) return;
      ref.read(stavUlozeniUzivateluProvider.notifier).state = (
        text: chyba.message,
        chyba: true,
      );
      _ukazChybu(context, chyba.message);
    }
  }

  Future<void> _otevri(String email) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => UzivatelScreen(email: email)));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final prehled = ref.watch(prehledUzivateluProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.jakoZalozka,
        title: Text(
          'Uživatelé a práva',
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
                  : 'Uživatele se nepodařilo načíst.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (p) => LayoutBuilder(
          builder: (context, rozmery) {
            final vedleSebe = rozmery.maxWidth >= _sirkaVedleSebe;
            final dotaz = _hledani.trim().toLowerCase();
            final seznam = [
              for (final u in p.uzivatele)
                if (_filtr.plati(u) &&
                    (dotaz.isEmpty ||
                        '${u.jmeno ?? ''} ${u.email}'.toLowerCase().contains(
                          dotaz,
                        )))
                  u,
            ];
            final vybrany = _vybrany ?? seznam.firstOrNull?.email;
            final seznamKarta = _SeznamUzivatelu(
              prehled: p,
              seznam: seznam,
              filtr: _filtr,
              vybrany: vedleSebe ? vybrany : null,
              vedleSebe: vedleSebe,
              onHledani: (t) => setState(() => _hledani = t),
              onFiltr: (f) => setState(() => _filtr = f),
              onVyber: (u) => vedleSebe
                  ? setState(() => _vybrany = u.email)
                  : _otevri(u.email),
              onPridat: (email) => _pridat(email, vedleSebe: vedleSebe),
            );

            if (!vedleSebe) {
              return RefreshIndicator.adaptive(
                onRefresh: () => ref.refresh(prehledUzivateluProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.xs,
                    Insets.lg,
                    Insets.giant,
                  ),
                  children: [
                    const _Uvod(),
                    const SizedBox(height: Insets.md),
                    seznamKarta,
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.xs,
                Insets.xl,
                Insets.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Uvod(),
                  const SizedBox(height: Insets.md),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 380,
                          child: SingleChildScrollView(child: seznamKarta),
                        ),
                        const SizedBox(width: Insets.xl),
                        Expanded(
                          child: vybrany == null
                              ? const SizedBox.shrink()
                              : SingleChildScrollView(
                                  child: _Karta(
                                    child: DetailUzivatele(
                                      key: ValueKey(vybrany),
                                      email: vybrany,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Podtitulek a stavový řádek se zelenou tečkou.
class _Uvod extends ConsumerWidget {
  const _Uvod();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final stav = ref.watch(stavUlozeniUzivateluProvider);
    final barva = stav?.chyba == true
        ? AppColors.danger
        : _Barvy.of(context).zapis;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Insets.lg,
      runSpacing: Insets.xs,
      children: [
        Text(
          'Vyberte uživatele a nastavte mu práva. Změna se uloží hned.',
          style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: barva, shape: BoxShape.circle),
            ),
            const SizedBox(width: Insets.xs),
            Flexible(
              child: Text(
                stav?.text ?? 'Změny se ukládají hned.',
                key: const Key('uzivatele-stav'),
                style: AppTextStyles.metaSmall.copyWith(
                  color: stav?.chyba == true
                      ? AppColors.danger
                      : palette.muted2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SeznamUzivatelu extends StatefulWidget {
  const _SeznamUzivatelu({
    required this.prehled,
    required this.seznam,
    required this.filtr,
    required this.vybrany,
    required this.vedleSebe,
    required this.onHledani,
    required this.onFiltr,
    required this.onVyber,
    required this.onPridat,
  });

  final PrehledUzivatelu prehled;
  final List<UzivatelSpravy> seznam;
  final FiltrUzivatelu filtr;
  final String? vybrany;
  final bool vedleSebe;
  final ValueChanged<String> onHledani;
  final ValueChanged<FiltrUzivatelu> onFiltr;
  final ValueChanged<UzivatelSpravy> onVyber;
  final ValueChanged<String> onPridat;

  @override
  State<_SeznamUzivatelu> createState() => _SeznamUzivateluState();
}

class _SeznamUzivateluState extends State<_SeznamUzivatelu> {
  final _novy = TextEditingController();

  @override
  void dispose() {
    _novy.dispose();
    super.dispose();
  }

  bool get _platny => _novy.text.trim().contains('@');

  void _pridej() {
    if (!_platny) return;
    widget.onPridat(_novy.text.trim().toLowerCase());
    _novy.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    final p = widget.prehled;
    return _Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('uzivatele-hledani'),
                  onChanged: widget.onHledani,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Hledat jméno nebo e-mail…',
                    filled: true,
                    fillColor: palette.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.input),
                      borderSide: BorderSide(color: palette.hairline2),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in FiltrUzivatelu.values)
                      _Cip(
                        key: Key('filtr-${f.name}'),
                        popisek: f.popisek,
                        pocet: p.uzivatele.where(f.plati).length,
                        aktivni: widget.filtr == f,
                        barva: barvy.navy,
                        onTap: () => widget.onFiltr(f),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.hairline),
          for (final u in widget.seznam)
            _RadekUzivatele(
              uzivatel: u,
              poradace: p.poradace,
              souhrn: souhrnPrav(u, p.poradace, pobockyPlanu: p.pobockyPlanu),
              vybrany: u.email == widget.vybrany,
              onTap: () => widget.onVyber(u),
            ),
          if (widget.seznam.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Text(
                'Nikdo takový tu není.',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardBody.copyWith(color: palette.muted),
              ),
            ),
          Container(
            color: palette.background,
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('uzivatel-novy-email'),
                    controller: _novy,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _pridej(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'e-mail nového uživatele',
                      filled: true,
                      fillColor: palette.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.input),
                        borderSide: BorderSide(color: palette.hairline2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                FilledButton.icon(
                  key: const Key('uzivatel-novy-pridat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: barvy.navy,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _platny ? _pridej : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Přidat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cip extends StatelessWidget {
  const _Cip({
    super.key,
    required this.popisek,
    required this.pocet,
    required this.aktivni,
    required this.barva,
    required this.onTap,
  });

  final String popisek;
  final int pocet;
  final bool aktivni;
  final Color barva;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = aktivni ? Colors.white : palette.muted2;
    return Material(
      color: aktivni ? barva : palette.card,
      shape: StadiumBorder(
        side: BorderSide(color: aktivni ? barva : palette.hairline2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text.rich(
            TextSpan(
              text: '$popisek ',
              children: [
                TextSpan(
                  text: '$pocet',
                  style: TextStyle(color: text.withValues(alpha: 0.7)),
                ),
              ],
            ),
            style: AppTextStyles.metaSmall.copyWith(
              color: text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadekUzivatele extends StatelessWidget {
  const _RadekUzivatele({
    required this.uzivatel,
    required this.poradace,
    required this.souhrn,
    required this.vybrany,
    required this.onTap,
  });

  final UzivatelSpravy uzivatel;
  final List<PoradacSpravy> poradace;
  final String souhrn;
  final bool vybrany;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    final u = uzivatel;
    return Material(
      color: vybrany
          ? AppColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        key: Key('uzivatel-${u.email}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: vybrany ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: palette.hairline),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(11, 12, 10, 12),
          child: Row(
            children: [
              _Avatar(jmeno: u.popisek, velikost: 38, navy: u.jeAdmin),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            u.popisek,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardBody.copyWith(
                              color: palette.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (u.jeAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'ADMIN',
                              style: AppTextStyles.metaSmall.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: barvy.cteniText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      souhrn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: [
                        for (final p in poradace)
                          Tooltip(
                            message:
                                '${p.nazev}: ${_pravoText(u.jeAdmin ? 'W' : u.prava[p.kod])}',
                            child: Container(
                              width: 14,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: switch (u.jeAdmin
                                    ? 'W'
                                    : u.prava[p.kod]) {
                                  'W' => barvy.zapis,
                                  'R' => AppColors.accent,
                                  _ => barvy.nic,
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
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

/// Detail uživatele na telefonu - samostatná obrazovka.
class UzivatelScreen extends StatelessWidget {
  const UzivatelScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Uživatel',
          style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.xs,
          Insets.lg,
          Insets.giant,
        ),
        children: [_Karta(child: DetailUzivatele(email: email))],
      ),
    );
  }
}

/// Detail: role, pořadače (Všem nastavit) a plánovač po pobočkách se
/// spínačem kapacity. Každá změna se hned uloží.
class DetailUzivatele extends ConsumerStatefulWidget {
  const DetailUzivatele({super.key, required this.email});

  final String email;

  @override
  ConsumerState<DetailUzivatele> createState() => _DetailUzivateleState();
}

class _DetailUzivateleState extends ConsumerState<DetailUzivatele> {
  /// Rozpracovaná podoba - ukáže se hned, ještě než služba odpoví.
  UzivatelSpravy? _upraveny;
  bool _uklada = false;

  Future<void> _zmen(UzivatelSpravy novy, String popis) async {
    final puvodni = _upraveny;
    final stav = ref.read(stavUlozeniUzivateluProvider.notifier);
    setState(() {
      _upraveny = novy;
      _uklada = true;
    });
    try {
      await ulozUzivatele(ref, novy);
      stav.state = (text: 'Uloženo · ${novy.popisek} · $popis', chyba: false);
    } on ServiceOrderException catch (chyba) {
      stav.state = (text: chyba.message, chyba: true);
      if (!mounted) return;
      setState(() => _upraveny = puvodni);
      _ukazChybu(context, chyba.message);
    } finally {
      if (mounted) setState(() => _uklada = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    final prehled = ref.watch(prehledUzivateluProvider).valueOrNull;
    final ja = ref.watch(currentEmployeeProvider)?.email.toLowerCase();
    final ulozeny = prehled?.uzivatele
        .where((u) => u.email == widget.email)
        .firstOrNull;
    final u = _upraveny ?? ulozeny ?? UzivatelSpravy(email: widget.email);
    final jsemTo = ja == u.email;
    if (prehled == null) {
      return const Padding(
        padding: EdgeInsets.all(Insets.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_uklada) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: EdgeInsets.fromLTRB(
            Insets.xl,
            _uklada ? Insets.xl - 2 : Insets.xl,
            Insets.xl,
            Insets.xl,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Insets.lg,
            runSpacing: Insets.md,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Avatar(jmeno: u.popisek, velikost: 56, navy: true),
                  const SizedBox(width: Insets.lg),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.popisek,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: palette.text,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            u.email,
                            if (u.prihlasen == null)
                              'zatím se nepřihlásil'
                            else
                              'naposledy ${AppDateFormat.date(u.prihlasen!)}, '
                                  '${AppDateFormat.time(u.prihlasen!)}',
                          ].join(' · '),
                          style: AppTextStyles.metaSmall.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Prepinac(
                    key: const Key('uzivatel-role'),
                    volby: const [
                      ('user', 'Uživatel', null),
                      ('admin', 'Admin', _BarvaVolby.admin),
                    ],
                    hodnota: u.role,
                    povoleno: !jsemTo && !_uklada,
                    onZmena: (role) => _zmen(
                      u.copyWith(role: role),
                      'role → ${role == 'admin' ? 'Admin' : 'Uživatel'}',
                    ),
                  ),
                  if (jsemTo) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sám sobě roli admina vzít nemůžete.',
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.hairline),
        if (u.jeAdmin)
          Container(
            key: const Key('uzivatel-admin-info'),
            margin: const EdgeInsets.all(Insets.xl),
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: barvy.cteniText),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin smí všechno',
                        style: AppTextStyles.cardBody.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Zápis u všech pořadačů, plánuje ve všech pobočkách '
                        'klempírny a spravuje uživatele. Jednotlivá práva se '
                        'u admina nenastavují.',
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.muted2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          _Sekce(
            nadpis: 'POŘADAČE ZAKÁZEK',
            vpravo: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  'Všem nastavit:',
                  style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
                ),
                for (final (pravo, popisek) in const [
                  ('W', 'Zápis'),
                  ('R', 'Čtení'),
                  ('', 'Nic'),
                ])
                  _MaleTlacitko(
                    key: Key('vsem-${pravo.isEmpty ? 'nic' : pravo}'),
                    popisek: popisek,
                    pozadi: switch (pravo) {
                      'W' => barvy.zapisPozadi,
                      'R' => barvy.cteniPozadi,
                      _ => palette.card,
                    },
                    text: switch (pravo) {
                      'W' => barvy.zapisText,
                      'R' => barvy.cteniText,
                      _ => palette.muted2,
                    },
                    okraj: pravo.isEmpty ? palette.hairline2 : null,
                    onTap: _uklada
                        ? null
                        : () => _zmen(
                            u.copyWith(
                              prava: {
                                if (pravo.isNotEmpty)
                                  for (final p in prehled.poradace)
                                    p.kod: pravo,
                              },
                            ),
                            'všechny pořadače → ${_pravoText(pravo)}',
                          ),
                  ),
              ],
            ),
            radky: [
              for (final p in prehled.poradace)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.sm,
                    Insets.sm,
                    Insets.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nazev,
                          style: AppTextStyles.cardBody.copyWith(
                            color: palette.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _Prepinac(
                        key: Key('pravo-${p.kod}'),
                        volby: const [
                          ('', '–', null),
                          ('R', 'Čtení', _BarvaVolby.cteni),
                          ('W', 'Zápis', _BarvaVolby.zapis),
                        ],
                        hodnota: u.prava[p.kod] ?? '',
                        povoleno: !_uklada,
                        onZmena: (pravo) {
                          final prava = {...u.prava};
                          if (pravo.isEmpty) {
                            prava.remove(p.kod);
                          } else {
                            prava[p.kod] = pravo;
                          }
                          _zmen(
                            u.copyWith(prava: prava),
                            '${p.nazev} → ${_pravoText(pravo)}',
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
            legenda: [
              ('Zápis', barvy.zapisText, ' čtení i změny · '),
              ('Čtení', barvy.cteniText, ' jen prohlíží · '),
              ('–', palette.text, ' zakázky pořadače nevidí'),
            ],
          ),
          if (prehled.pobockyPlanu.isNotEmpty)
            _Sekce(
              nadpis: 'PLÁNOVAČ KLEMPÍRNY',
              radky: [
                for (final p in prehled.pobockyPlanu)
                  LayoutBuilder(
                    builder: (context, c) {
                      // Na telefonu pobočka nad volbami, jinak sloupec vlevo.
                      final uzky = c.maxWidth < 440;
                      final pobocka = Container(
                        width: uzky ? null : 110,
                        color: palette.background,
                        padding: uzky
                            ? const EdgeInsets.symmetric(
                                horizontal: Insets.lg,
                                vertical: Insets.sm,
                              )
                            : const EdgeInsets.all(Insets.md),
                        alignment: Alignment.topLeft,
                        child: Text(
                          p.nazev,
                          style: AppTextStyles.metaSmall.copyWith(
                            color: palette.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                      final volby = Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Insets.sm,
                          Insets.xs,
                          Insets.sm,
                          Insets.xs,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: Insets.md,
                          runSpacing: Insets.xs,
                          children: [
                            _SpinacKapacity(
                              key: Key('kapacita-${p.kod}'),
                              zapnuto: u.kapacita.contains(p.kod),
                              povoleno: u.planovac[p.kod] != null && !_uklada,
                              onZmena: (ano) => _zmen(
                                u.copyWith(
                                  kapacita: ano
                                      ? {...u.kapacita, p.kod}
                                      : ({...u.kapacita}..remove(p.kod)),
                                ),
                                'kapacita ${p.nazev} '
                                '${ano ? 'zapnuta' : 'vypnuta'}',
                              ),
                            ),
                            _Prepinac(
                              key: Key('planovac-${p.kod}'),
                              volby: const [
                                ('', '–', null),
                                ('R', 'Prohlížet', _BarvaVolby.cteni),
                                ('W', 'Plánovat', _BarvaVolby.zapis),
                              ],
                              hodnota: u.planovac[p.kod] ?? '',
                              povoleno: !_uklada,
                              onZmena: (pravo) {
                                final planovac = {...u.planovac};
                                // Bez přístupu k pobočce kapacitu nemá -
                                // po vrácení by se sama neobnovila.
                                final kapacita = {...u.kapacita};
                                if (pravo.isEmpty) {
                                  planovac.remove(p.kod);
                                  kapacita.remove(p.kod);
                                } else {
                                  planovac[p.kod] = pravo;
                                }
                                _zmen(
                                  u.copyWith(
                                    planovac: planovac,
                                    kapacita: kapacita,
                                  ),
                                  'plánovač ${p.nazev} → ${switch (pravo) {
                                    'W' => 'Plánovat',
                                    'R' => 'Prohlížet',
                                    _ => 'nic',
                                  }}',
                                );
                              },
                            ),
                          ],
                        ),
                      );
                      return uzky
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [pobocka, volby],
                            )
                          : IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  pobocka,
                                  Expanded(child: volby),
                                ],
                              ),
                            );
                    },
                  ),
              ],
              legenda: [
                ('Plánovat', barvy.zapisText, ' plán i dílenský stav · '),
                (
                  'Prohlížet',
                  barvy.cteniText,
                  ' jen vidí · kapacitu dílen upravuje mistr klempírny '
                      'a vedoucí servisu',
                ),
              ],
            ),
          const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }
}

/// Sekce detailu: nadpis (vpravo volitelně akce), rámeček s řádky, legenda.
class _Sekce extends StatelessWidget {
  const _Sekce({
    required this.nadpis,
    required this.radky,
    required this.legenda,
    this.vpravo,
  });

  final String nadpis;
  final Widget? vpravo;
  final List<Widget> radky;

  /// (tučně, barva tučného, zbytek textu).
  final List<(String, Color, String)> legenda;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Na telefonu užší okraje, ať se přepínače vejdou vedle názvu.
    final okraj = MediaQuery.sizeOf(context).width < 600
        ? Insets.md
        : Insets.xl;
    return Padding(
      padding: EdgeInsets.fromLTRB(okraj, Insets.xl, okraj, Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Insets.lg,
            runSpacing: Insets.xs,
            children: [
              Text(
                nadpis,
                style: AppTextStyles.overline.copyWith(color: palette.muted),
              ),
              ?vpravo,
            ],
          ),
          const SizedBox(height: Insets.sm),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.hairline2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, r) in radky.indexed) ...[
                  if (i > 0) Divider(height: 1, color: palette.hairline),
                  r,
                ],
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text.rich(
            TextSpan(
              children: [
                for (final (tucne, barva, zbytek) in legenda) ...[
                  TextSpan(
                    text: tucne,
                    style: TextStyle(color: barva, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: zbytek),
                ],
              ],
            ),
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

enum _BarvaVolby { zapis, cteni, admin }

/// Segmentový přepínač jako na webu: (hodnota, popisek, barva vybrané).
class _Prepinac extends StatelessWidget {
  const _Prepinac({
    super.key,
    required this.volby,
    required this.hodnota,
    required this.povoleno,
    required this.onZmena,
  });

  final List<(String, String, _BarvaVolby?)> volby;
  final String hodnota;
  final bool povoleno;
  final ValueChanged<String> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: barvy.segment,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (h, popisek, barva)) in volby.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Builder(
              builder: (context) {
                final vybrana = h == hodnota;
                final (pozadi, text, okraj) = !vybrana
                    ? (Colors.transparent, palette.muted, null)
                    : switch (barva) {
                        _BarvaVolby.zapis => (
                          barvy.zapisPozadi,
                          barvy.zapisText,
                          barvy.zapisText,
                        ),
                        _BarvaVolby.cteni => (
                          barvy.cteniPozadi,
                          barvy.cteniText,
                          barvy.cteniText,
                        ),
                        _BarvaVolby.admin => (barvy.navy, Colors.white, null),
                        null => (palette.card, palette.text, palette.hairline2),
                      };
                return Semantics(
                  button: true,
                  selected: vybrana,
                  child: Material(
                    color: pozadi,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                      side: okraj == null
                          ? BorderSide.none
                          : BorderSide(color: okraj.withValues(alpha: 0.5)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: povoleno && !vybrana ? () => onZmena(h) : null,
                      child: Container(
                        height: 30,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          popisek,
                          style: AppTextStyles.metaSmall.copyWith(
                            fontSize: 13,
                            color: povoleno || vybrana
                                ? text
                                : text.withValues(alpha: 0.6),
                            fontWeight: vybrana
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// „Upravuje kapacitu" - bez práva k pobočce v plánovači zašedlý.
class _SpinacKapacity extends StatelessWidget {
  const _SpinacKapacity({
    super.key,
    required this.zapnuto,
    required this.povoleno,
    required this.onZmena,
  });

  final bool zapnuto;
  final bool povoleno;
  final ValueChanged<bool> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = _Barvy.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: povoleno ? () => onZmena(!zapnuto) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 20,
              padding: const EdgeInsets.all(2),
              alignment: zapnuto ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: zapnuto
                    ? barvy.navy
                    : povoleno
                    ? barvy.nic
                    : palette.plate,
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              'Upravuje kapacitu',
              style: AppTextStyles.metaSmall.copyWith(
                fontSize: 13,
                color: povoleno
                    ? palette.text
                    : palette.muted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaleTlacitko extends StatelessWidget {
  const _MaleTlacitko({
    super.key,
    required this.popisek,
    required this.pozadi,
    required this.text,
    required this.onTap,
    this.okraj,
  });

  final String popisek;
  final Color pozadi;
  final Color text;
  final Color? okraj;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pozadi,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: okraj == null ? BorderSide.none : BorderSide(color: okraj!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            popisek,
            style: AppTextStyles.metaSmall.copyWith(
              color: text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.jmeno,
    required this.velikost,
    required this.navy,
  });

  final String jmeno;
  final double velikost;
  final bool navy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: velikost,
      height: velikost,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: navy ? _Barvy.of(context).navy : palette.avatar,
      ),
      child: Text(
        inicialyUzivatele(jmeno),
        style: AppTextStyles.cardBody.copyWith(
          color: navy ? Colors.white : palette.text,
          fontWeight: FontWeight.w700,
          fontSize: velikost > 40 ? 19 : 13,
        ),
      ),
    );
  }
}

class _Karta extends StatelessWidget {
  const _Karta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Barvy práv - stejné jako pásma vytížení v plánovači a na webu.
class _Barvy {
  const _Barvy._({
    required this.zapis,
    required this.zapisPozadi,
    required this.zapisText,
    required this.cteniPozadi,
    required this.cteniText,
    required this.nic,
    required this.segment,
    required this.navy,
  });

  /// Proužek a tečka zápisu.
  final Color zapis;
  final Color zapisPozadi;
  final Color zapisText;
  final Color cteniPozadi;
  final Color cteniText;

  /// Proužek „nic" a vypnutý spínač.
  final Color nic;

  /// Podklad segmentového přepínače.
  final Color segment;

  /// Admin, aktivní filtr, zapnutý spínač - v tmavém režimu modřejší, ať
  /// navy na tmavém pozadí nezmizí.
  final Color navy;

  factory _Barvy.of(BuildContext context) {
    final tmava = context.isDarkMode;
    return _Barvy._(
      zapis: tmava ? const Color(0xFF5FD38D) : const Color(0xFF2E9E5B),
      zapisPozadi: tmava ? const Color(0x295FD38D) : const Color(0xFFE3F5EA),
      zapisText: tmava ? const Color(0xFF5FD38D) : const Color(0xFF1B6E3C),
      cteniPozadi: tmava ? const Color(0x294599FE) : const Color(0xFFEAF2FC),
      cteniText: tmava ? const Color(0xFF8CC0FF) : const Color(0xFF1F4F8F),
      nic: tmava ? const Color(0x3DFFFFFF) : const Color(0xFFC9D6DE),
      segment: tmava ? const Color(0x14FFFFFF) : const Color(0xFFEEF2F4),
      navy: tmava ? AppColors.repairBlue : AppColors.primary,
    );
  }
}

String _pravoText(String? pravo) => switch (pravo) {
  'W' => 'zápis',
  'R' => 'čtení',
  _ => 'nic',
};

void _ukazChybu(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
