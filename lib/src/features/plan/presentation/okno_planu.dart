import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/akce_providers.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/presentation/controllers/order_actions_controller.dart';
import '../../orders/presentation/widgets/okno_zapisu.dart';

/// „12. 10. – 14. 10. 2026", přes rok s rokem u obou.
String obdobiPlanu(DateTime od, DateTime do_) {
  final zacatek = od.year == do_.year
      ? AppDateFormat.dayMonth(od)
      : AppDateFormat.date(od);
  return '$zacatek – ${AppDateFormat.date(do_)}';
}

/// Okno plánu zakázky na klempírně/lakovně - z detailu zakázky i z pruhu
/// v záložce Plán. Bez [plan] se zakládá nový.
Future<void> naplanovatKlempirnu(
  BuildContext context,
  WidgetRef ref, {
  required String zakazkaId,
  String? spz,
  PlanKlempirny? plan,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OknoPlanu(
      zakazkaId: zakazkaId,
      spz: spz,
      plan: plan,
      autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
    ),
  );
}

class _OknoPlanu extends ConsumerStatefulWidget {
  const _OknoPlanu({
    required this.zakazkaId,
    required this.spz,
    required this.plan,
    required this.autor,
  });

  final String zakazkaId;
  final String? spz;
  final PlanKlempirny? plan;
  final String autor;

  @override
  ConsumerState<_OknoPlanu> createState() => _OknoPlanuState();
}

class _OknoPlanuState extends ConsumerState<_OknoPlanu> {
  late DateTimeRange? _obdobi = widget.plan == null
      ? null
      : DateTimeRange(start: widget.plan!.od, end: widget.plan!.do_);
  late final _kod = TextEditingController(text: widget.plan?.kodLaku ?? '');
  late final _poznamka = TextEditingController(
    text: widget.plan?.poznamka ?? '',
  );
  late bool _hotovo = widget.plan?.hotovo ?? false;
  bool _uklada = false;
  String? _chyba;

  @override
  void dispose() {
    _kod.dispose();
    _poznamka.dispose();
    super.dispose();
  }

  bool get _lzeUlozit => !_uklada && _obdobi != null;

  Future<void> _vyberObdobi() async {
    final dnes = ref.read(dnesProvider);
    final vybrano = await showDateRangePicker(
      context: context,
      firstDate: dnes.subtract(const Duration(days: 365)),
      lastDate: dnes.add(const Duration(days: 365)),
      initialDateRange: _obdobi,
      currentDate: dnes,
      helpText: 'Klempírna / lakovna od – do',
      // Ne „Hotovo" - tak se v okně jmenuje stav plánu.
      saveText: 'Použít',
    );
    if (vybrano != null && mounted) setState(() => _obdobi = vybrano);
  }

  /// Uloží nebo zruší plán; chyba zůstane v okně.
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

  Future<void> _uloz() async {
    final obdobi = _obdobi;
    if (!_lzeUlozit || obdobi == null) return;
    final kod = _kod.text.trim().toUpperCase();
    await _proved(
      () => ref
          .read(orderActionsProvider.notifier)
          .ulozPlanKlempirny(
            widget.zakazkaId,
            PlanKlempirny(
              od: obdobi.start,
              do_: obdobi.end,
              kodLaku: kod.isEmpty ? null : kod,
              poznamka: _poznamka.text.trim(),
              hotovo: _hotovo,
            ),
          ),
    );
  }

  Future<void> _zrus() async {
    final ano = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Zrušit plán?'),
        content: const Text('Zakázka zmizí z plánu klempírny.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ponechat'),
          ),
          TextButton(
            key: const Key('plan-zrusit-potvrdit'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zrušit plán'),
          ),
        ],
      ),
    );
    if (ano != true || !mounted) return;
    await _proved(
      () => ref
          .read(orderActionsProvider.notifier)
          .zrusPlanKlempirny(widget.zakazkaId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final obdobi = _obdobi;
    final cervena = context.isDarkMode
        ? const Color(0xFFFF7A7A)
        : AppColors.danger;

    return OknoZapisu(
      nadpis: widget.plan == null
          ? 'Zaplánovat na klempírnu/lakovnu'
          : 'Upravit plán',
      kam: 'klempírna / lakovna',
      spz: widget.spz,
      cisloZakazky: widget.zakazkaId,
      autor: widget.autor,
      potvrdit: widget.plan == null ? 'Zaplánovat' : 'Uložit',
      potvrditKey: const Key('plan-ulozit'),
      onPotvrdit: _lzeUlozit ? _uloz : null,
      obsah: [
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
        const SizedBox(height: Insets.sm),
        SwitchListTile.adaptive(
          key: const Key('plan-hotovo'),
          contentPadding: EdgeInsets.zero,
          value: _hotovo,
          activeTrackColor: AppColors.readyGreen,
          onChanged: (hotovo) => setState(() => _hotovo = hotovo),
          title: Text(
            'Hotovo',
            style: AppTextStyles.cardBody.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Klempírna a lakovna mají vůz za sebou.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ),
        if (_chyba != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _chyba!,
            key: const Key('plan-chyba'),
            style: AppTextStyles.metaSmall.copyWith(color: cervena),
          ),
        ],
        if (widget.plan != null) ...[
          const SizedBox(height: Insets.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('plan-zrusit'),
              onPressed: _uklada ? null : _zrus,
              style: TextButton.styleFrom(foregroundColor: cervena),
              icon: const Icon(Icons.event_busy_outlined, size: 20),
              label: const Text('Zrušit plán'),
            ),
          ),
        ],
      ],
    );
  }
}
