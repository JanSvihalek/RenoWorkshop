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

/// Soubory protokolu - až po rozbalení podrobných protokolů.
final souboryDiagnostikyProvider = FutureProvider.autoDispose
    .family<List<SouborDiagnostiky>, (String, String)>((ref, klic) async {
      final zdroj = _zdroj(ref);
      if (zdroj == null) return const [];
      return zdroj.souboryProtokolu(klic.$1, klic.$2);
    });

/// Karta Diagnostika v detailu zakázky - protokoly BMW ISPI ze serveru
/// pobočky. Klepnutí otevře finální report, podrobné protokoly (ISPA,
/// ISTA) jsou pod rozbalením.
class DiagnostikaKarta extends ConsumerStatefulWidget {
  const DiagnostikaKarta({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DiagnostikaKarta> createState() => _DiagnostikaKartaState();
}

class _DiagnostikaKartaState extends ConsumerState<DiagnostikaKarta> {
  /// Id souboru, který se právě stahuje - jeden naráz.
  String? _otevira;

  /// Protokol s rozbalenými podrobnými protokoly.
  String? _rozbaleny;

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
          for (final p in seznam) ...[
            _Radek(
              key: Key('diagnostika-${p.id}'),
              ikona: Icons.monitor_heart_outlined,
              nazev: 'Diagnostika ${AppDateFormat.dateTime(p.cas)}',
              popis: p.zdroj,
              otevira: _otevira == p.hlavniId,
              onTap: () => _otevri(p.id, p.hlavniId, p.hlavniNazev),
            ),
            TextButton.icon(
              key: Key('diagnostika-podrobne-${p.id}'),
              onPressed: () =>
                  setState(() => _rozbaleny = _rozbaleny == p.id ? null : p.id),
              icon: Icon(
                _rozbaleny == p.id
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _rozbaleny == p.id
                    ? 'Skrýt podrobné protokoly'
                    : 'Podrobné protokoly (ISPA, ISTA)',
              ),
            ),
            if (_rozbaleny == p.id)
              _Podrobne(
                orderId: widget.orderId,
                protokol: p,
                otevira: _otevira,
                onOtevri: (s) => _otevri(p.id, s.id, s.nazev),
              ),
          ],
        ],
      );
    }

    return DetailCard(
      key: const Key('diagnostika-karta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            seznam.isEmpty
                ? 'ISTA/ISPA PROTOKOLY'
                : 'ISTA/ISPA PROTOKOLY  ${seznam.length}',
          ),
          const SizedBox(height: Insets.sm),
          obsah,
        ],
      ),
    );
  }
}

class _Podrobne extends ConsumerWidget {
  const _Podrobne({
    required this.orderId,
    required this.protokol,
    required this.otevira,
    required this.onOtevri,
  });

  final String orderId;
  final ProtokolDiagnostiky protokol;
  final String? otevira;
  final ValueChanged<SouborDiagnostiky> onOtevri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final soubory = ref.watch(
      souboryDiagnostikyProvider((orderId, protokol.id)),
    );
    Widget text(String t) => Padding(
      padding: const EdgeInsets.only(left: Insets.xl, bottom: Insets.sm),
      child: Text(
        t,
        style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
      ),
    );

    return soubory.when(
      loading: () => text('Načítám soubory…'),
      error: (chyba, _) => text(
        chyba is ServiceOrderException
            ? chyba.message
            : 'Soubory se nepodařilo načíst.',
      ),
      data: (vse) {
        final podrobne = [
          for (final s in vse)
            if (!s.hlavni) s,
        ];
        if (podrobne.isEmpty) {
          return text('Podrobné protokoly ve složce nejsou.');
        }
        return Padding(
          padding: const EdgeInsets.only(left: Insets.xl),
          child: Column(
            children: [
              for (final s in podrobne)
                _Radek(
                  key: Key('diagnostika-soubor-${s.id}'),
                  ikona: Icons.description_outlined,
                  nazev: s.nazev,
                  popis: [?s.slozka, velikostSouboru(s.velikost)].join(' · '),
                  otevira: otevira == s.id,
                  onTap: () => onOtevri(s),
                ),
            ],
          ),
        );
      },
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
            Icon(ikona, color: AppColors.accent, size: 24),
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
