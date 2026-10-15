import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../../orders/presentation/widgets/okno_zapisu.dart';
import '../domain/kampan_podle_stari.dart';
import 'akce_providers.dart';

/// Okno pro novou kampaň podle stáří (bez [kampan]) nebo úpravu - jen
/// pro správce, z Nastavení.
Future<void> upravitKampanStari(
  BuildContext context,
  WidgetRef ref, {
  KampanPodleStari? kampan,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OknoKampaneStari(
      kampan: kampan,
      autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
    ),
  );
}

class _OknoKampaneStari extends ConsumerStatefulWidget {
  const _OknoKampaneStari({required this.kampan, required this.autor});

  final KampanPodleStari? kampan;
  final String autor;

  @override
  ConsumerState<_OknoKampaneStari> createState() => _OknoKampaneStariState();
}

class _OknoKampaneStariState extends ConsumerState<_OknoKampaneStari> {
  late final _nazev = TextEditingController(text: widget.kampan?.nazev ?? '');
  late final _text = TextEditingController(text: widget.kampan?.text ?? '');
  late final _od = TextEditingController(
    text: '${widget.kampan?.odMesicu ?? 48}',
  );
  late final _do = TextEditingController(
    text: widget.kampan?.doMesicu?.toString() ?? '',
  );
  late bool _aktivni = widget.kampan?.aktivni ?? true;
  bool _uklada = false;
  String? _chyba;

  @override
  void dispose() {
    _nazev.dispose();
    _text.dispose();
    _od.dispose();
    _do.dispose();
    super.dispose();
  }

  /// Rozsah stáří, nebo důvod, proč nesedí.
  ({int od, int? do_})? get _rozsah {
    final od = int.tryParse(_od.text.trim());
    final doText = _do.text.trim();
    final do_ = doText.isEmpty ? null : int.tryParse(doText);
    if (od == null || od < 0) return null;
    if (doText.isNotEmpty && (do_ == null || do_ <= od)) return null;
    return (od: od, do_: do_);
  }

  bool get _lzeUlozit =>
      !_uklada && _nazev.text.trim().isNotEmpty && _rozsah != null;

  Future<void> _uloz() async {
    final rozsah = _rozsah;
    if (!_lzeUlozit || rozsah == null) return;
    setState(() {
      _uklada = true;
      _chyba = null;
    });
    try {
      await ref
          .read(kampaneStariProvider.notifier)
          .uloz(
            KampanPodleStari(
              id: widget.kampan?.id,
              nazev: _nazev.text.trim(),
              text: _text.text.trim(),
              odMesicu: rozsah.od,
              doMesicu: rozsah.do_,
              aktivni: _aktivni,
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cervena = context.isDarkMode
        ? const Color(0xFFFF7A7A)
        : AppColors.danger;
    final spatnyRozsah =
        _rozsah == null && (_od.text.isNotEmpty || _do.text.isNotEmpty);

    return OknoZapisu(
      nadpis: widget.kampan == null
          ? 'Nová kampaň podle stáří'
          : 'Upravit kampaň',
      kam: 'stáří od první registrace vozu',
      autor: widget.autor,
      potvrdit: 'Uložit',
      potvrditKey: const Key('kampan-stari-ulozit'),
      onPotvrdit: _lzeUlozit ? _uloz : null,
      obsah: [
        const PopisekPole('NÁZEV'),
        PoleZapisu(
          poleKey: const Key('kampan-stari-nazev'),
          controller: _nazev,
          napoveda: 'Např. FitServis+',
          maxDelka: 200,
          autofocus: widget.kampan == null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Insets.base),
        const PopisekPole('TEXT'),
        PoleZapisu(
          poleKey: const Key('kampan-stari-text'),
          controller: _text,
          napoveda: 'Co kampaň nabízí - ukáže se po klepnutí na štítek.',
          maxDelka: 4000,
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: Insets.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PopisekPole('OD MĚSÍCŮ'),
                  PoleZapisu(
                    poleKey: const Key('kampan-stari-od'),
                    controller: _od,
                    napoveda: '48',
                    maxDelka: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PopisekPole('DO MĚSÍCŮ'),
                  PoleZapisu(
                    poleKey: const Key('kampan-stari-do'),
                    controller: _do,
                    napoveda: 'bez omezení',
                    maxDelka: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Text(
          spatnyRozsah
              ? 'Stáří se zadává v celých měsících; „do" musí být víc než „od".'
              : 'Vůz spadá do kampaně, když je mu aspoň „od" měsíců '
                    '(a méně než „do", je-li vyplněné).',
          key: const Key('kampan-stari-napoveda'),
          style: AppTextStyles.metaSmall.copyWith(
            color: spatnyRozsah ? cervena : palette.muted,
          ),
        ),
        const SizedBox(height: Insets.base),
        SwitchListTile.adaptive(
          key: const Key('kampan-stari-aktivni'),
          contentPadding: EdgeInsets.zero,
          value: _aktivni,
          activeTrackColor: AppColors.accent,
          onChanged: (zapnout) => setState(() => _aktivni = zapnout),
          title: Text(
            'Zapnutá',
            style: AppTextStyles.cardBody.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Vypnutá se u vozů neukazuje.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ),
        if (_chyba != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _chyba!,
            key: const Key('kampan-stari-chyba'),
            style: AppTextStyles.metaSmall.copyWith(color: cervena),
          ),
        ],
      ],
    );
  }
}
