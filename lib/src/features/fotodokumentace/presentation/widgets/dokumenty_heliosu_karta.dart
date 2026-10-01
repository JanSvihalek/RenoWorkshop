import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/log_udalosti_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../domain/entities/dokument.dart';
import '../controllers/fotky_providers.dart';
import '../prace_s_dokumenty.dart';

/// Karta Dokumenty Helios v detailu zakázky - zakázkový list a další
/// dokumenty, které Helios uložil do EDM. Jen ke čtení; klepnutím se
/// dokument stáhne a otevře.
///
/// Dokumentů u zakázky bývá pár, proto jsou rovnou v kartě, bez další
/// obrazovky.
class DokumentyHeliosuKarta extends ConsumerStatefulWidget {
  const DokumentyHeliosuKarta({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DokumentyHeliosuKarta> createState() =>
      _DokumentyHeliosuKartaState();
}

class _DokumentyHeliosuKartaState extends ConsumerState<DokumentyHeliosuKarta> {
  /// Id dokumentu, který se právě stahuje - jeden naráz.
  String? _otevira;

  void _oznam(String zprava) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(zprava)));
  }

  /// Do logu jen přípona, ne jméno - bývá v něm číslo zakázky nebo faktury.
  void _logChyba(Object chyba, String nazev, [StackTrace? zasobnik]) {
    final tecka = nazev.lastIndexOf('.');
    ref
        .read(logUdalostiProvider)
        .chyba(
          'dokument_heliosu_neotevren',
          chyba,
          zasobnik: zasobnik,
          detail: tecka < 0 ? null : nazev.substring(tecka + 1),
        );
  }

  Future<void> _otevri(Dokument dokument) async {
    if (_otevira != null) return;
    setState(() => _otevira = dokument.id);
    try {
      final data = await ref
          .read(fotkyDataSourceProvider)
          .stahniDokument(widget.orderId, dokument.id);
      await ref.read(praceSDokumentyProvider).otevri(dokument.nazev, data);
    } on ServiceOrderException catch (chyba) {
      _logChyba(chyba.message, dokument.nazev);
      _oznam(chyba.message);
    } on PraceSDokumentyException catch (chyba) {
      _logChyba(chyba.message, dokument.nazev);
      _oznam(chyba.message);
    } catch (chyba, zasobnik) {
      _logChyba(chyba, dokument.nazev, zasobnik);
      _oznam('Dokument se nepodařilo otevřít.');
    } finally {
      if (mounted) setState(() => _otevira = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dokumenty = ref.watch(dokumentyHeliosuProvider(widget.orderId));
    final seznam = dokumenty.valueOrNull ?? const <Dokument>[];

    final Widget obsah;
    if (dokumenty.hasError && !dokumenty.hasValue) {
      obsah = Row(
        children: [
          Expanded(
            child: Text(
              'Dokumenty z Heliosu se nepodařilo načíst.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          ),
          TextButton(
            key: const Key('dokumenty-heliosu-znovu'),
            onPressed: () =>
                ref.invalidate(dokumentyHeliosuProvider(widget.orderId)),
            child: const Text('Znovu'),
          ),
        ],
      );
    } else if (!dokumenty.hasValue) {
      obsah = Text(
        'Načítám dokumenty…',
        style: AppTextStyles.cardBody.copyWith(color: palette.muted),
      );
    } else if (seznam.isEmpty) {
      obsah = Text(
        'Helios u zakázky žádné dokumenty nemá.',
        style: AppTextStyles.cardBody.copyWith(color: palette.muted),
      );
    } else {
      obsah = Column(
        children: [
          for (final dokument in seznam)
            _Radek(
              dokument: dokument,
              otevira: _otevira == dokument.id,
              onTap: () => _otevri(dokument),
            ),
        ],
      );
    }

    return DetailCard(
      key: const Key('dokumenty-heliosu'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('DOKUMENTY HELIOS')),
              if (seznam.isNotEmpty)
                Text(
                  pocetDokumentu(seznam.length),
                  style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          obsah,
        ],
      ),
    );
  }
}

class _Radek extends StatelessWidget {
  const _Radek({
    required this.dokument,
    required this.otevira,
    required this.onTap,
  });

  final Dokument dokument;
  final bool otevira;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final zmeneno = dokument.zmenenoAt;

    return InkWell(
      key: Key('dokument-heliosu-${dokument.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          children: [
            Icon(dokument.ikona, color: AppColors.accent, size: 26),
            const SizedBox(width: Insets.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dokument.nazev,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (zmeneno != null)
                    Text(
                      AppDateFormat.dateTime(zmeneno),
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
