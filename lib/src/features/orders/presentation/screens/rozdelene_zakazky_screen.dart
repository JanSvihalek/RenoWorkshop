import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/rozlozeni.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/tablet_shell.dart';
import '../../../../core/widgets/workshop_bottom_nav.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/orders_providers.dart';
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
    required this.onSelectTab,
    required this.onSearchArchive,
    required this.onScanCode,
  });

  final ValueChanged<WorkshopTab> onSelectTab;
  final ValueChanged<String> onSearchArchive;
  final VoidCallback onScanCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vybrana = ref.watch(vybranaZakazkaProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: TabletShell(
        active: WorkshopTab.orders,
        onSelect: onSelectTab,
        child: Row(
          children: [
            SizedBox(
              width: Rozlozeni.sirkaSeznamu,
              child: OrdersListScreen(
                vRozdelenem: true,
                vybranaId: vybrana,
                onOpenOrder: (ServiceOrder order) =>
                    ref.read(vybranaZakazkaProvider.notifier).state = order.id,
                onSelectTab: onSelectTab,
                onSearchArchive: onSearchArchive,
                onScanCode: onScanCode,
              ),
            ),
            Container(width: 1, color: palette.hairline),
            Expanded(
              child: vybrana == null
                  ? const _PrazdnyDetail()
                  : OrderDetailScreen(
                      // Bez klíče by se při přepnutí zakázky recykloval
                      // stav předchozího detailu (rozbalené karty, posun).
                      key: ValueKey(vybrana),
                      orderId: vybrana,
                      onBack: () =>
                          ref.read(vybranaZakazkaProvider.notifier).state =
                              null,
                      zobrazitZpet: false,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pravý sloupec, dokud si člověk zakázku nevybere.
class _PrazdnyDetail extends StatelessWidget {
  const _PrazdnyDetail();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      color: palette.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 44,
              color: palette.muted.withValues(alpha: 0.45),
            ),
            const SizedBox(height: Insets.base),
            Text(
              'Vyberte zakázku ze seznamu',
              style: AppTextStyles.metaSmall.copyWith(
                fontSize: 13,
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
