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

/// Uživatelé a jejich práva (Nastavení → Uživatelé, jen admin). Seznam
/// s hledáním a shrnutím práv; klepnutím detail uživatele. Stejná data
/// jako stránka Uživatelé na webu.
class UzivateleScreen extends ConsumerStatefulWidget {
  const UzivateleScreen({super.key, this.jakoZalozka = false});

  /// Záložka Admin v hlavní navigaci - nadpis „Admin" a sekce Uživatelé
  /// a práva (další nastavení admina přibudou pod ni). Jinak samostatná
  /// obrazovka (z plánovače) se šipkou zpět.
  final bool jakoZalozka;

  @override
  ConsumerState<UzivateleScreen> createState() => _UzivateleScreenState();
}

class _UzivateleScreenState extends ConsumerState<UzivateleScreen> {
  String _hledani = '';

  Future<void> _pridat() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _NovyUzivatel(),
    );
    if (email == null || !mounted) return;
    try {
      await ulozUzivatele(ref, UzivatelSpravy(email: email));
      if (!mounted) return;
      final prehled = await ref.read(prehledUzivateluProvider.future);
      if (!mounted) return;
      final novy = prehled.uzivatele.firstWhere(
        (u) => u.email == email,
        orElse: () => UzivatelSpravy(email: email),
      );
      await _otevri(novy);
    } on ServiceOrderException catch (chyba) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(chyba.message)));
      }
    }
  }

  Future<void> _otevri(UzivatelSpravy uzivatel) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UzivatelScreen(email: uzivatel.email),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final prehled = ref.watch(prehledUzivateluProvider);
    final dotaz = _hledani.trim().toLowerCase();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.jakoZalozka,
        title: Text(
          widget.jakoZalozka ? 'Admin' : 'Uživatelé',
          style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
        ),
        actions: [
          IconButton(
            key: const Key('uzivatel-pridat'),
            tooltip: 'Přidat uživatele',
            onPressed: _pridat,
            icon: Icon(Icons.person_add_alt_1_outlined, color: palette.text),
          ),
        ],
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
        data: (p) {
          final seznam = [
            for (final u in p.uzivatele)
              if (dotaz.isEmpty ||
                  '${u.jmeno ?? ''} ${u.email}'.toLowerCase().contains(dotaz))
                u,
          ];
          return RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(prehledUzivateluProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.sm,
                Insets.xl,
                Insets.giant,
              ),
              children: [
                if (widget.jakoZalozka)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: Insets.xxs,
                      bottom: Insets.sm,
                    ),
                    child: Text(
                      'UŽIVATELÉ A PRÁVA',
                      style: AppTextStyles.overline.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                TextField(
                  key: const Key('uzivatele-hledani'),
                  onChanged: (t) => setState(() => _hledani = t),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Hledat jméno nebo e-mail',
                    filled: true,
                    fillColor: palette.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.input),
                      borderSide: BorderSide(color: palette.hairline2),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        for (final (i, u) in seznam.indexed) ...[
                          if (i > 0)
                            Divider(height: 1, color: palette.hairline),
                          _RadekUzivatele(
                            uzivatel: u,
                            souhrn: souhrnPrav(u, p.poradace),
                            onTap: () => _otevri(u),
                          ),
                        ],
                        if (seznam.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: Text(
                              'Nikdo takový tu není.',
                              style: AppTextStyles.cardBody.copyWith(
                                color: palette.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  'Nový uživatel se založí sám při prvním přihlášení - se '
                  'zápisem u pořadačů své pobočky podle Heliosu.',
                  style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RadekUzivatele extends StatelessWidget {
  const _RadekUzivatele({
    required this.uzivatel,
    required this.souhrn,
    required this.onTap,
  });

  final UzivatelSpravy uzivatel;
  final String souhrn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      key: Key('uzivatel-${uzivatel.email}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.base,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uzivatel.popisek,
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (uzivatel.jmeno != null)
                    Text(
                      uzivatel.email,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    souhrn,
                    style: AppTextStyles.metaSmall.copyWith(
                      color: uzivatel.jeAdmin ? AppColors.accent : palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.muted),
          ],
        ),
      ),
    );
  }
}

class _NovyUzivatel extends StatefulWidget {
  const _NovyUzivatel();

  @override
  State<_NovyUzivatel> createState() => _NovyUzivatelState();
}

class _NovyUzivatelState extends State<_NovyUzivatel> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _platny => _email.text.trim().contains('@');

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: const Text('Nový uživatel'),
      content: Material(
        type: MaterialType.transparency,
        child: TextField(
          key: const Key('uzivatel-novy-email'),
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'jmeno@renocar.cz'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(
          key: const Key('uzivatel-novy-pridat'),
          onPressed: _platny
              ? () =>
                    Navigator.of(context).pop(_email.text.trim().toLowerCase())
              : null,
          child: const Text('Přidat'),
        ),
      ],
    );
  }
}

/// Detail uživatele: role a u pořadačů po pobočkách Zápis / Čtení / –.
/// Každá změna se hned uloží.
class UzivatelScreen extends ConsumerStatefulWidget {
  const UzivatelScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<UzivatelScreen> createState() => _UzivatelScreenState();
}

class _UzivatelScreenState extends ConsumerState<UzivatelScreen> {
  /// Rozpracovaná podoba - ukáže se hned, ještě než služba odpoví.
  UzivatelSpravy? _upraveny;
  bool _uklada = false;

  Future<void> _zmen(UzivatelSpravy novy) async {
    final puvodni = _upraveny;
    setState(() {
      _upraveny = novy;
      _uklada = true;
    });
    try {
      await ulozUzivatele(ref, novy);
    } on ServiceOrderException catch (chyba) {
      if (!mounted) return;
      setState(() => _upraveny = puvodni);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(chyba.message)));
    } finally {
      if (mounted) setState(() => _uklada = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final prehled = ref.watch(prehledUzivateluProvider).valueOrNull;
    final ja = ref.watch(currentEmployeeProvider)?.email.toLowerCase();
    final ulozeny = prehled?.uzivatele
        .where((u) => u.email == widget.email)
        .firstOrNull;
    final u = _upraveny ?? ulozeny ?? UzivatelSpravy(email: widget.email);
    final jsemTo = ja == u.email;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          u.popisek,
          style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
        ),
        bottom: _uklada
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: prehled == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.sm,
                Insets.xl,
                Insets.giant,
              ),
              children: [
                Text(
                  [
                    u.email,
                    u.prihlasen == null
                        ? 'zatím se nepřihlásil'
                        : 'naposledy ${AppDateFormat.date(u.prihlasen!)} '
                              '${AppDateFormat.time(u.prihlasen!)}',
                  ].join(' · '),
                  style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
                ),
                const SizedBox(height: Insets.lg),
                _Skupina(
                  nadpis: 'ROLE',
                  poznamka: jsemTo
                      ? 'Sám sobě roli admin vzít nemůžete.'
                      : 'Admin smí všechno, včetně správy uživatelů.',
                  deti: [
                    Padding(
                      padding: const EdgeInsets.all(Insets.md),
                      child: SegmentedButton<String>(
                        key: const Key('uzivatel-role'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'user', label: Text('Uživatel')),
                          ButtonSegment(value: 'admin', label: Text('Admin')),
                        ],
                        selected: {u.role},
                        onSelectionChanged: jsemTo || _uklada
                            ? null
                            : (v) => _zmen(u.copyWith(role: v.first)),
                      ),
                    ),
                  ],
                ),
                if (!u.jeAdmin)
                  _Skupina(
                    nadpis: 'PLÁNOVAČ',
                    poznamka:
                        'Plánovač klempírny zvlášť od zakázek. Plánovat jde '
                        'jen u pořadačů se zápisem.',
                    deti: [
                      Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: SegmentedButton<String>(
                          key: const Key('uzivatel-planovac'),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'planovat',
                              label: Text('Plánovat'),
                            ),
                            ButtonSegment(
                              value: 'cist',
                              label: Text('Prohlížet'),
                            ),
                            ButtonSegment(value: 'zadne', label: Text('–')),
                          ],
                          selected: {u.planovac},
                          onSelectionChanged: _uklada
                              ? null
                              : (v) => _zmen(u.copyWith(planovac: v.first)),
                        ),
                      ),
                    ],
                  ),
                if (u.jeAdmin)
                  Text(
                    'Admin má zápis u všech pořadačů a plánuje.',
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.muted,
                    ),
                  )
                else
                  for (final (pobocka, poradace) in poradacePoPobockach(
                    prehled.poradace,
                  ))
                    _Skupina(
                      nadpis: pobocka.toUpperCase(),
                      deti: [
                        for (final p in poradace)
                          _RadekPoradace(
                            poradac: p,
                            pravo: u.prava[p.kod],
                            povoleno: !_uklada,
                            onZmena: (pravo) {
                              final prava = {...u.prava};
                              if (pravo == null) {
                                prava.remove(p.kod);
                              } else {
                                prava[p.kod] = pravo;
                              }
                              _zmen(u.copyWith(prava: prava));
                            },
                          ),
                      ],
                    ),
              ],
            ),
    );
  }
}

class _RadekPoradace extends StatelessWidget {
  const _RadekPoradace({
    required this.poradac,
    required this.pravo,
    required this.povoleno,
    required this.onZmena,
  });

  final PoradacSpravy poradac;
  final String? pravo;
  final bool povoleno;
  final ValueChanged<String?> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              poradac.nazev,
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SegmentedButton<String>(
            key: Key('pravo-${poradac.kod}'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: '', label: Text('–')),
              ButtonSegment(value: 'R', label: Text('Čtení')),
              ButtonSegment(value: 'W', label: Text('Zápis')),
            ],
            selected: {pravo ?? ''},
            onSelectionChanged: povoleno
                ? (v) => onZmena(v.first.isEmpty ? null : v.first)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Karta se skupinou voleb - nadpis nad ní, poznámka pod ní.
class _Skupina extends StatelessWidget {
  const _Skupina({required this.nadpis, required this.deti, this.poznamka});

  final String nadpis;
  final List<Widget> deti;
  final String? poznamka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Insets.xxs, bottom: Insets.sm),
            child: Text(
              nadpis,
              style: AppTextStyles.overline.copyWith(color: palette.muted),
            ),
          ),
          Container(
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
          ),
          if (poznamka != null)
            Padding(
              padding: const EdgeInsets.only(left: Insets.xxs, top: Insets.sm),
              child: Text(
                poznamka!,
                style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
              ),
            ),
        ],
      ),
    );
  }
}
