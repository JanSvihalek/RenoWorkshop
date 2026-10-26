import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/log_udalosti_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../fotodokumentace/presentation/prace_s_dokumenty.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../../orders/presentation/widgets/detail_cards.dart';
import '../data/diagnostika_data_source.dart';
import '../domain/diagnostika.dart';

DiagnostikaDataSource? _zdroj(Ref ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  return zdroj is DiagnostikaDataSource ? zdroj as DiagnostikaDataSource : null;
}

/// Protokoly zakázky. Zdroj bez diagnostiky (starší služba) vrátí prázdno.
final diagnostikaZakazkyProvider = FutureProvider.autoDispose
    .family<List<ProtokolDiagnostiky>, String>((ref, orderId) async {
      final zdroj = _zdroj(ref);
      if (zdroj == null) return const [];
      try {
        return await zdroj.protokolyZakazky(orderId);
      } on ServiceOrderException {
        rethrow;
      } catch (chyba) {
        throw ServiceOrderException('Diagnostiku se nepodařilo načíst: $chyba');
      }
    });

/// Soubory případu (Final report, ISTA, ISPA, AWP…).
final souboryDiagnostikyProvider = FutureProvider.autoDispose
    .family<List<SouborDiagnostiky>, (String, String)>((ref, klic) async {
      final zdroj = _zdroj(ref);
      if (zdroj == null) return const [];
      return zdroj.souboryProtokolu(klic.$1, klic.$2);
    });

/// Karta ISTA/ISPA/AWP dokumenty v detailu zakázky - případy BMW ISPI ze
/// serveru pobočky. Ve složce případu není jen diagnostika, proto „Případ"
/// a pod ním všechny soubory, Final report první. Jako na webu.
class DiagnostikaKarta extends ConsumerStatefulWidget {
  const DiagnostikaKarta({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DiagnostikaKarta> createState() => _DiagnostikaKartaState();
}

class _DiagnostikaKartaState extends ConsumerState<DiagnostikaKarta> {
  /// Id souboru, který se právě stahuje - jeden naráz.
  String? _otevira;

  Future<void> _otevri(String protokolId, String souborId, String nazev) async {
    final zdroj = _zdrojZ(ref);
    if (_otevira != null || zdroj == null) return;
    setState(() => _otevira = souborId);
    void oznam(String zprava) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(zprava)));
    try {
      final data = await zdroj.stahniSouborDiagnostiky(
        widget.orderId,
        protokolId,
        souborId,
      );
      await ref.read(praceSDokumentyProvider).otevri(nazev, data);
    } on ServiceOrderException catch (chyba) {
      if (mounted) oznam(chyba.message);
    } on PraceSDokumentyException catch (chyba) {
      if (mounted) oznam(chyba.message);
    } catch (chyba, zasobnik) {
      ref
          .read(logUdalostiProvider)
          .chyba('diagnostika_neotevrena', chyba, zasobnik: zasobnik);
      if (mounted) oznam('Protokol se nepodařilo otevřít.');
    } finally {
      if (mounted) setState(() => _otevira = null);
    }
  }

  static DiagnostikaDataSource? _zdrojZ(WidgetRef ref) {
    final zdroj = ref.read(serviceOrderDataSourceProvider);
    return zdroj is DiagnostikaDataSource
        ? zdroj as DiagnostikaDataSource
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final protokoly = ref.watch(diagnostikaZakazkyProvider(widget.orderId));
    final seznam = protokoly.valueOrNull ?? const <ProtokolDiagnostiky>[];

    Widget text(String t) =>
        Text(t, style: AppTextStyles.cardBody.copyWith(color: palette.muted));

    final Widget obsah;
    if (protokoly.hasError && !protokoly.hasValue) {
      obsah = Row(
        children: [
          Expanded(child: text('Diagnostiku se nepodařilo načíst.')),
          TextButton(
            onPressed: () =>
                ref.invalidate(diagnostikaZakazkyProvider(widget.orderId)),
            child: const Text('Znovu'),
          ),
        ],
      );
    } else if (!protokoly.hasValue) {
      obsah = text('Načítám diagnostiku…');
    } else if (seznam.isEmpty) {
      obsah = text('K zakázce zatím není žádný protokol z diagnostiky.');
    } else {
      obsah = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in seznam)
            _Pripad(
              key: Key('diagnostika-${p.id}'),
              orderId: widget.orderId,
              protokol: p,
              otevira: _otevira,
              onOtevri: (id, nazev) => _otevri(p.id, id, nazev),
            ),
        ],
      );
    }

    return DetailCard(
      key: const Key('diagnostika-karta'),
      zIspi: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            seznam.isEmpty
                ? 'ISTA/ISPA/AWP DOKUMENTY'
                : 'ISTA/ISPA/AWP DOKUMENTY  ${seznam.length}',
            barva: AppColors.ispiModra(context),
          ),
          const SizedBox(height: Insets.sm),
          obsah,
        ],
      ),
    );
  }
}

class _Pripad extends ConsumerWidget {
  const _Pripad({
    super.key,
    required this.orderId,
    required this.protokol,
    required this.otevira,
    required this.onOtevri,
  });

  final String orderId;
  final ProtokolDiagnostiky protokol;
  final String? otevira;
  final void Function(String id, String nazev) onOtevri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final p = protokol;
    final soubory = ref.watch(souboryDiagnostikyProvider((orderId, p.id)));
    final vse = soubory.valueOrNull ?? const <SouborDiagnostiky>[];
    final hlavni = vse.where((s) => s.hlavni).firstOrNull;
    Widget text(String t) => Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        t,
        style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Insets.sm),
          child: Text(
            [
              'Případ ${AppDateFormat.dateTime(p.cas)}',
              if (p.zdroj.isNotEmpty) p.zdroj,
            ].join(' · '),
            style: AppTextStyles.cardBody.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // Final report je známý ze seznamu případů, ukáže se hned.
        _Radek(
          key: Key('diagnostika-hlavni-${p.id}'),
          ikona: Icons.picture_as_pdf_outlined,
          nazev: 'Final report',
          popis: hlavni == null ? '' : velikostSouboru(hlavni.velikost),
          otevira: otevira == p.hlavniId,
          onTap: () => onOtevri(p.hlavniId, p.hlavniNazev),
        ),
        for (final s in vse)
          if (!s.hlavni)
            _Radek(
              key: Key('diagnostika-soubor-${s.id}'),
              ikona: Icons.description_outlined,
              nazev: s.nazev,
              popis: [?s.slozka, velikostSouboru(s.velikost)].join(' · '),
              otevira: otevira == s.id,
              onTap: () => onOtevri(s.id, s.nazev),
            ),
        if (soubory.isLoading) text('Načítám další dokumenty…'),
        if (soubory.hasError)
          text(
            soubory.error is ServiceOrderException
                ? (soubory.error! as ServiceOrderException).message
                : 'Další dokumenty se nepodařilo načíst.',
          ),
      ],
    );
  }
}

class _Radek extends StatelessWidget {
  const _Radek({
    super.key,
    required this.ikona,
    required this.nazev,
    required this.popis,
    required this.otevira,
    required this.onTap,
  });

  final IconData ikona;
  final String nazev;
  final String popis;
  final bool otevira;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          children: [
            Icon(ikona, color: AppColors.ispiModra(context), size: 24),
            const SizedBox(width: Insets.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nazev,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (popis.isNotEmpty)
                    Text(
                      popis,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: otevira
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(Icons.open_in_new_rounded, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
