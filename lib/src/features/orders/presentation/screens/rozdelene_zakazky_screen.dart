import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/rozlozeni.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../akce/presentation/akce_panel.dart';
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
                : OrderDetailScreen(
                    // Bez klíče by se při přepnutí zakázky recykloval
                    // stav předchozího detailu (rozbalené karty, posun).
                    key: ValueKey(vybrana),
                    orderId: vybrana,
                    onBack: () =>
                        ref.read(vybranaZakazkaProvider.notifier).state = null,
                    zobrazitZpet: false,
                    onFotodokumentace: onFotodokumentace,
                    onSkenujObalku: onSkenujObalku,
                    onPrijem: onPrijem,
                  ),
          ),
        ],
      ),
    );
  }
}
