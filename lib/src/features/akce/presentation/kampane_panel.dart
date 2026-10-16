import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../../orders/presentation/widgets/okno_zapisu.dart';
import '../domain/technicka_kampan.dart';
import 'akce_providers.dart';

/// Barva technických kampaní - oranžová, ať se na první pohled liší od
/// modrých marketingových akcí. Na tmavém pozadí světlejší.
Color barvaKampani(BuildContext context) =>
    context.isDarkMode ? const Color(0xFFE8A93A) : const Color(0xFFB8740A);

/// Kolik kampaní - „1 technická kampaň", „3 technické kampaně", „5 …kampaní".
String pocetKampani(int n) =>
    '$n ${n == 1
        ? 'technická kampaň'
        : n >= 2 && n <= 4
        ? 'technické kampaně'
        : 'technických kampaní'}';

/// „1 VIN", „3 VINy", „5 VINů".
String pocetVinu(int n) =>
    '$n ${n == 1
        ? 'VIN'
        : n >= 2 && n <= 4
        ? 'VINy'
        : 'VINů'}';

/// Technické kampaně BMW: karty s kódem, názvem a počtem vozidel. Na
/// tabletu místo detailu nebo vysunuté přes něj, na telefonu jako
/// samostatná obrazovka.
class KampanePanel extends ConsumerWidget {
  const KampanePanel({super.key, this.napoveda, this.onZavrit});

  /// Řádek nad panelem - na tabletu „Vyberte zakázku ze seznamu".
  final String? napoveda;

  /// Křížek v hlavičce - panel vysunutý přes detail zakázky.
  final VoidCallback? onZavrit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prehled = ref.watch(kampaneProvider);
    final muze = prehled.valueOrNull?.muzeUpravovat ?? false;

    return RefreshIndicator.adaptive(
      onRefresh: ref.read(kampaneProvider.notifier).obnov,
      child: ListView(
        key: const Key('kampane-panel'),
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
              Icon(Icons.car_repair_outlined, size: 20, color: palette.text),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'Technické kampaně',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              if (muze)
                TextButton.icon(
                  key: const Key('kampane-pridat'),
                  onPressed: () => upravitKampan(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Přidat kampaň'),
                ),
              if (onZavrit != null)
                IconButton(
                  key: const Key('kampane-zavrit'),
                  onPressed: onZavrit,
                  tooltip: 'Zavřít',
                  icon: Icon(Icons.close_rounded, color: palette.muted2),
                ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Svolávací akce BMW. U zakázky se ukážou samy, když na ni sedí '
            'VIN vozu.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
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
                    : 'Kampaně se nepodařilo načíst.',
                style: AppTextStyles.cardBody.copyWith(color: palette.muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: ref.read(kampaneProvider.notifier).obnov,
                  child: const Text('Zkusit znovu'),
                ),
              ),
            ],
            data: (p) => p.kampane.isEmpty
                ? [
                    Text(
                      'Žádné technické kampaně.',
                      key: const Key('kampane-zadne'),
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ]
                : [
                    for (final kampan in p.kampane) ...[
                      _KartaKampane(
                        kampan: kampan,
                        onUpravit: muze
                            ? () => upravitKampan(context, ref, kampan: kampan)
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

class _KartaKampane extends StatelessWidget {
  const _KartaKampane({required this.kampan, this.onUpravit});

  final TechnickaKampan kampan;

  /// Jen správce akcí.
  final VoidCallback? onUpravit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barva = barvaKampani(context);

    // Oranžový proužek vlevo odliší kampaň od marketingové akce. Zaoblený
    // rámeček musí mít všechny strany stejné, proto proužek uvnitř.
    return Container(
      key: Key('kampan-${kampan.id}'),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card - 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: barva, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.base,
              Insets.sm,
              Insets.lg,
            ),
            child: _obsah(palette, barva),
          ),
        ),
      ),
    );
  }

  Widget _obsah(AppPalette palette, Color barva) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  kampan.nazev,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: palette.text,
                  ),
                ),
              ),
            ),
            if (onUpravit != null)
              IconButton(
                key: Key('kampan-upravit-${kampan.id}'),
                onPressed: onUpravit,
                tooltip: 'Upravit kampaň',
                icon: Icon(Icons.edit_outlined, size: 20, color: palette.muted),
              ),
          ],
        ),
        const SizedBox(height: Insets.xxs),
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (kampan.kod != null)
              Text(
                kampan.kod!,
                style: AppTextStyles.orderNumber.copyWith(
                  color: palette.muted2,
                ),
              ),
            Text(
              pocetVinu(kampan.pocetVozidel),
              style: AppTextStyles.metaSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: barva,
              ),
            ),
          ],
        ),
        if (kampan.text.trim().isNotEmpty) ...[
          const SizedBox(height: Insets.sm),
          Padding(
            padding: const EdgeInsets.only(right: Insets.sm),
            child: Text(
              kampan.text,
              style: AppTextStyles.noteText.copyWith(color: palette.text),
            ),
          ),
        ],
      ],
    );
  }
}

/// Druhý řádek pruhu nad seznamem zakázek: kolik je technických kampaní.
/// Klepnutí otevře přehled. Správce ho vidí i bez kampaní - jinak by
/// neměl kudy kampaň přidat.
class KampanePruh extends ConsumerWidget {
  const KampanePruh({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Schované i s dotazem na server (technickeKampaneZapnuteProvider).
    if (!ref.watch(technickeKampaneZapnuteProvider)) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    final prehled = ref.watch(kampaneProvider).valueOrNull;
    if (prehled == null) return const SizedBox.shrink();
    final kampane = prehled.kampane;
    if (kampane.isEmpty && !prehled.muzeUpravovat) {
      return const SizedBox.shrink();
    }
    final barva = barvaKampani(context);

    return Material(
      color: barva.withValues(alpha: 0.12),
      child: InkWell(
        key: const Key('kampane-pruh'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xl,
            vertical: Insets.md,
          ),
          child: Row(
            children: [
              Icon(Icons.car_repair_outlined, size: 18, color: barva),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: kampane.isEmpty
                            ? 'Technické kampaně'
                            : pocetKampani(kampane.length),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (kampane.isNotEmpty)
                        TextSpan(text: ' · ${kampane.first.nazev}'),
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

/// Okno pro novou kampaň (bez [kampan]) nebo úpravu - jen pro správce.
Future<void> upravitKampan(
  BuildContext context,
  WidgetRef ref, {
  TechnickaKampan? kampan,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OknoKampane(
      kampan: kampan,
      autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
    ),
  );
}

class _OknoKampane extends ConsumerStatefulWidget {
  const _OknoKampane({required this.kampan, required this.autor});

  final TechnickaKampan? kampan;
  final String autor;

  @override
  ConsumerState<_OknoKampane> createState() => _OknoKampaneState();
}

class _OknoKampaneState extends ConsumerState<_OknoKampane> {
  late final _kod = TextEditingController(text: widget.kampan?.kod ?? '');
  late final _nazev = TextEditingController(text: widget.kampan?.nazev ?? '');
  late final _text = TextEditingController(text: widget.kampan?.text ?? '');
  final _viny = TextEditingController();

  /// U úpravy se VINy nejdřív načtou - do té doby se nedá uložit.
  late bool _nacita = widget.kampan != null;
  bool _uklada = false;
  String? _chyba;

  @override
  void initState() {
    super.initState();
    final id = widget.kampan?.id;
    if (id != null) _nactiViny(id);
  }

  Future<void> _nactiViny(String id) async {
    try {
      final viny = await ref.read(kampaneProvider.notifier).viny(id);
      if (!mounted) return;
      _viny.text = viny.join('\n');
      setState(() => _nacita = false);
    } on ServiceOrderException catch (chyba) {
      if (mounted) {
        setState(() {
          _nacita = false;
          _chyba = chyba.message;
        });
      }
    }
  }

  @override
  void dispose() {
    _kod.dispose();
    _nazev.dispose();
    _text.dispose();
    _viny.dispose();
    super.dispose();
  }

  ({List<String> platne, List<String> neplatne}) get _rozpoznane =>
      rozpoznejViny(_viny.text);

  bool get _lzeUlozit {
    final r = _rozpoznane;
    return !_uklada &&
        !_nacita &&
        _nazev.text.trim().isNotEmpty &&
        r.platne.isNotEmpty &&
        r.neplatne.isEmpty;
  }

  Future<void> _uloz() async {
    if (!_lzeUlozit) return;
    setState(() {
      _uklada = true;
      _chyba = null;
    });
    final kod = _kod.text.trim();
    final kampan = TechnickaKampan(
      id: widget.kampan?.id,
      kod: kod.isEmpty ? null : kod,
      nazev: _nazev.text.trim(),
      text: _text.text.trim(),
    );
    try {
      await ref.read(kampaneProvider.notifier).uloz(kampan, _rozpoznane.platne);
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
    final id = widget.kampan?.id;
    if (id == null) return;
    final ano = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Smazat kampaň?'),
        content: Text(
          'Kampaň „${widget.kampan!.nazev}" zmizí všem i u zakázek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            key: const Key('kampan-smazat-potvrdit'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (ano != true || !mounted) return;
    try {
      await ref.read(kampaneProvider.notifier).smaz(id);
      if (mounted) Navigator.of(context).pop();
    } on ServiceOrderException catch (chyba) {
      if (mounted) setState(() => _chyba = chyba.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final r = _rozpoznane;
    final cervena = context.isDarkMode
        ? const Color(0xFFFF7A7A)
        : AppColors.danger;

    return OknoZapisu(
      nadpis: widget.kampan == null
          ? 'Nová technická kampaň'
          : 'Upravit kampaň',
      kam: 'ukáže se u zakázek s těmito VINy',
      autor: widget.autor,
      potvrdit: 'Uložit',
      potvrditKey: const Key('kampan-ulozit'),
      onPotvrdit: _lzeUlozit ? _uloz : null,
      obsah: [
        const PopisekPole('ČÍSLO KAMPANĚ'),
        PoleZapisu(
          poleKey: const Key('kampan-kod'),
          controller: _kod,
          napoveda: 'Např. 0032760300 (nepovinné)',
          maxDelka: 40,
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('NÁZEV'),
        PoleZapisu(
          poleKey: const Key('kampan-nazev'),
          controller: _nazev,
          napoveda: 'Např. Výměna airbagu spolujezdce',
          maxDelka: 200,
          autofocus: widget.kampan == null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('CO SE DĚLÁ'),
        PoleZapisu(
          poleKey: const Key('kampan-text'),
          controller: _text,
          napoveda: 'Postup, díly, doba práce…',
          maxDelka: 4000,
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('VINY'),
        if (_nacita)
          const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          PoleZapisu(
            poleKey: const Key('kampan-viny'),
            controller: _viny,
            napoveda:
                'Vložte VINy z Excelu nebo z portálu BMW - každý na řádek. '
                'Stačí i posledních 7 znaků.',
            maxDelka: 400000,
            minLines: 4,
            maxLines: 10,
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: Insets.sm),
        if (!_nacita && (r.platne.isNotEmpty || r.neplatne.isNotEmpty))
          Text(
            'Rozpoznáno ${pocetVinu(r.platne.length)}',
            key: const Key('kampan-pocet-vinu'),
            style: AppTextStyles.metaSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.muted2,
            ),
          ),
        if (r.neplatne.isNotEmpty) ...[
          const SizedBox(height: Insets.xxs),
          Text(
            'Neplatné (VIN má 17 znaků, krátký 7): '
            '${r.neplatne.take(5).join(', ')}'
            '${r.neplatne.length > 5 ? ' a další' : ''}',
            key: const Key('kampan-neplatne'),
            style: AppTextStyles.metaSmall.copyWith(color: cervena),
          ),
        ],
        if (_chyba != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _chyba!,
            key: const Key('kampan-chyba'),
            style: AppTextStyles.metaSmall.copyWith(color: cervena),
          ),
        ],
        if (widget.kampan != null) ...[
          const SizedBox(height: Insets.base),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('kampan-smazat'),
              onPressed: _uklada ? null : _smaz,
              style: TextButton.styleFrom(foregroundColor: cervena),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Smazat kampaň'),
            ),
          ),
        ],
      ],
    );
  }
}
