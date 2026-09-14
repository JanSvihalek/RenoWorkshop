import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/rozlozeni.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../controllers/vozidla_providers.dart';
import 'karta_vozidla_screen.dart';
import 'vyhledavani_screen.dart';

/// Vyhledávání na tabletu: výsledky vlevo, karta vozidla vpravo.
///
/// Stejné rozložení jako zakázky. Karta se neotevírá přes výsledky,
/// takže jde projít několik vozidel se stejnou SPZ bez vracení.
class RozdeleneVyhledavaniScreen extends ConsumerWidget {
  const RozdeleneVyhledavaniScreen({
    super.key,
    required this.onScan,
    required this.onOpenOrder,
  });

  final VoidCallback onScan;
  final Future<void> Function(ServiceOrder order) onOpenOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vybrane = ref.watch(vybraneVozidloProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: Row(
        children: [
          SizedBox(
            width: Rozlozeni.sirkaSeznamu,
            child: VyhledavaniScreen(
              vybraneId: vybrane,
              onScan: onScan,
              onOpenVozidlo: (vozidlo) =>
                  ref.read(vybraneVozidloProvider.notifier).state = vozidlo.id,
            ),
          ),
          Container(width: 1, color: palette.hairline),
          Expanded(
            child: vybrane == null
                ? const _PrazdnaKarta()
                : KartaVozidlaScreen(
                    key: ValueKey(vybrane),
                    vozidloId: vybrane,
                    zobrazitZpet: false,
                    onBack: () =>
                        ref.read(vybraneVozidloProvider.notifier).state = null,
                    onOpenOrder: onOpenOrder,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PrazdnaKarta extends StatelessWidget {
  const _PrazdnaKarta();

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
              Icons.directions_car_outlined,
              size: 44,
              color: palette.muted.withValues(alpha: 0.45),
            ),
            const SizedBox(height: Insets.base),
            Text(
              'Vyberte vozidlo',
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
