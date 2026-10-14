import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/rozlozeni.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../akce/presentation/akce_panel.dart';
import '../../../akce/presentation/akce_providers.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/orders_providers.dart';
import '../widgets/obalka_klice.dart';
import 'order_detail_screen.dart';
import 'orders_list_screen.dart';

/// Zakázky na tabletu: navigace, seznam a detail vedle sebe.
///
/// Na dílenském tabletu se zakázky proklikávají jedna za druhou (obchůzka
/// po stáních), takže se vyplatí mít seznam pořád na očích. Detail se
/// proto neotvírá přes seznam, ale mění se sloupec vpravo.
///
/// Marketingové akce jsou obecná informace, ne součást zakázky: pruh s nimi
/// je nahoře v seznamu zakázek a klepnutí vysune panel přes detail (detail
/// zůstane široký). Bez vybrané zakázky je panel rovnou místo detailu.
class RozdeleneZakazkyScreen extends ConsumerWidget {
  const RozdeleneZakazkyScreen({
    super.key,
    required this.onScanCode,
    required this.onFotodokumentace,
    required this.onPrijem,
    this.onSkenujObalku,
  });

  final VoidCallback onScanCode;
  final ValueChanged<String> onFotodokumentace;
  final ValueChanged<String> onPrijem;
  final SkenujObalku? onSkenujObalku;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vybrana = ref.watch(vybranaZakazkaProvider);
    final akceOtevrene = ref.watch(akcePanelOtevrenyProvider);
    void prepniAkce(bool otevrit) =>
        ref.read(akcePanelOtevrenyProvider.notifier).state = otevrit;

    return Scaffold(
      backgroundColor: palette.background,
      body: Row(
        children: [
          SizedBox(
            width: Rozlozeni.sirkaSeznamu,
            child: OrdersListScreen(
              vRozdelenem: true,
              vybranaId: vybrana,
              onOpenOrder: (ServiceOrder order) =>
                  ref.read(vybranaZakazkaProvider.notifier).state = order.id,
              onScanCode: onScanCode,
              // Bez vybrané zakázky je panel akcí vidět i tak.
              onOpenAkce: () {
                if (vybrana != null) prepniAkce(!akceOtevrene);
              },
            ),
          ),
          Container(width: 1, color: palette.hairline),
          Expanded(
            // Dokud není vybraná zakázka, je vpravo přehled marketingových
            // akcí - místo, které by jinak jen čekalo.
            child: vybrana == null
                ? ColoredBox(
                    color: palette.background,
                    child: const AkcePanel(
                      napoveda: 'Vyberte zakázku ze seznamu',
                    ),
                  )
                : _DetailSAkcemi(
                    otevreno: akceOtevrene,
                    onZavrit: () => prepniAkce(false),
                    detail: OrderDetailScreen(
                      // Bez klíče by se při přepnutí zakázky recykloval
                      // stav předchozího detailu (rozbalené karty, posun).
                      key: ValueKey(vybrana),
                      orderId: vybrana,
                      onBack: () =>
                          ref.read(vybranaZakazkaProvider.notifier).state =
                              null,
                      zobrazitZpet: false,
                      onFotodokumentace: onFotodokumentace,
                      onSkenujObalku: onSkenujObalku,
                      onPrijem: onPrijem,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Detail zakázky a přes něj vysouvací panel marketingových akcí.
/// Klepnutí vedle panelu ho zavře.
class _DetailSAkcemi extends StatelessWidget {
  const _DetailSAkcemi({
    required this.detail,
    required this.otevreno,
    required this.onZavrit,
  });

  final Widget detail;
  final bool otevreno;
  final VoidCallback onZavrit;

  static const _trvani = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sirka = (constraints.maxWidth * 0.75).clamp(320.0, 460.0);
        return Stack(
          children: [
            Positioned.fill(child: detail),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !otevreno,
                child: AnimatedOpacity(
                  opacity: otevreno ? 1 : 0,
                  duration: _trvani,
                  child: GestureDetector(
                    onTap: onZavrit,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: _trvani,
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              width: sirka,
              right: otevreno ? 0 : -sirka - 24,
              child: DecoratedBox(
                key: const Key('akce-vysunuty-panel'),
                decoration: BoxDecoration(
                  color: palette.background,
                  boxShadow: otevreno
                      ? const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 24,
                            offset: Offset(-4, 0),
                          ),
                        ]
                      : null,
                ),
                child: otevreno
                    ? AkcePanel(onZavrit: onZavrit)
                    : const SizedBox(),
              ),
            ),
          ],
        );
      },
    );
  }
}
