import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/log_udalosti_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../controllers/fotky_providers.dart';
import '../prace_s_dokumenty.dart';

/// Karta Protokol zakázky v detailu: PDF s opisem zakázky ve složce na
/// Foto-doc. Server ho obnovuje sám po změnách; tlačítko ho vytvoří hned
/// a otevře - třeba když ho poradce potřebuje poslat zákazníkovi.
class ProtokolKarta extends ConsumerStatefulWidget {
  const ProtokolKarta({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ProtokolKarta> createState() => _ProtokolKartaState();
}

class _ProtokolKartaState extends ConsumerState<ProtokolKarta> {
  bool _vytvari = false;

  void _oznam(String zprava) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(zprava)));
  }

  Future<void> _otevri() async {
    if (_vytvari) return;
    setState(() => _vytvari = true);
    final log = ref.read(logUdalostiProvider);
    try {
      final zdroj = ref.read(fotkyDataSourceProvider);
      final protokol = await zdroj.vytvorProtokol(widget.orderId);
      // Protokol je ve složce i mezi dokumenty zakázky.
      ref.invalidate(dokumentyZakazkyProvider(widget.orderId));
      final data = await zdroj.stahniDokument(widget.orderId, protokol.id);
      await ref.read(praceSDokumentyProvider).otevri(protokol.nazev, data);
      log.udalost('protokol_otevren', zakazka: widget.orderId);
    } on ServiceOrderException catch (chyba) {
      log.chyba('protokol_neotevren', chyba.message);
      _oznam(chyba.message);
    } on PraceSDokumentyException catch (chyba) {
      log.chyba('protokol_neotevren', chyba.message);
      _oznam(chyba.message);
    } catch (chyba, zasobnik) {
      log.chyba('protokol_neotevren', chyba, zasobnik: zasobnik);
      _oznam('Protokol se nepodařilo otevřít.');
    } finally {
      if (mounted) setState(() => _vytvari = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DetailCard(
      key: const Key('protokol-karta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('PROTOKOL ZAKÁZKY'),
          const SizedBox(height: Insets.sm),
          Text(
            'Souhrn zakázky v PDF ve složce zakázky. Po změnách v aplikaci '
            'se sám obnoví.',
            style: AppTextStyles.cardBody.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.base),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('otevrit-protokol'),
              onPressed: _vytvari ? null : _otevri,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
              ),
              icon: _vytvari
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(_vytvari ? 'Vytvářím…' : 'Otevřít aktuální protokol'),
            ),
          ),
        ],
      ),
    );
  }
}
