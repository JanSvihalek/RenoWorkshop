import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../controllers/vozidla_providers.dart';
import '../widgets/identifikace_vozidla_karta.dart';

/// Výsledek hledání vozidla přes celou obrazovku: karta vozu se všemi
/// údaji jako identifikace v příjmu a pod ní všechny zakázky.
///
/// Zakázky jsou rozdělané i ukončené, od nejnovější - tatáž karta jako
/// v seznamu dílny, takže stav z Heliosu a dílenský stav jsou vidět hned.
class KartaVozidlaScreen extends ConsumerWidget {
  const KartaVozidlaScreen({
    super.key,
    required this.vozidloId,
    required this.onBack,
    required this.onOpenOrder,
    this.naskenovano = false,
    this.onNeniToOno,
  });

  final int vozidloId;
  final VoidCallback onBack;

  /// Otevře detail zakázky a počká na návrat - karta se pak načte znovu,
  /// ať je vidět stav, který mezitím někdo přidal.
  final Future<void> Function(ServiceOrder order) onOpenOrder;

  /// Vůz se našel podle naskenované SPZ - jen do popisku na kartě.
  final bool naskenovano;

  /// Nalezený vůz to není: zpět k hledání a znovu skener.
  final VoidCallback? onNeniToOno;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final karta = ref.watch(kartaVozidlaProvider(vozidloId));

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _Hlavicka(onBack: onBack),
          Expanded(
            child: karta.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (chyba, _) => _Sdeleni('$chyba'),
              data: (vozidlo) {
                if (vozidlo == null) {
                  return const _Sdeleni('Vozidlo nebylo nalezeno.');
                }

                // Karta i zakázky stejně široké a uprostřed - na tabletu
                // by se jinak roztáhly přes celou šířku.
                Widget naStred(Widget dite) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: dite,
                  ),
                );

                return RefreshIndicator.adaptive(
                  onRefresh: () async =>
                      ref.invalidate(kartaVozidlaProvider(vozidloId)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xl,
                      Insets.xl,
                      Insets.xl,
                      Insets.giant,
                    ),
                    children: [
                      naStred(
                        IdentifikaceVozidlaKarta(
                          vozidlo: vozidlo,
                          naskenovano: naskenovano,
                          onNeniToOno: onNeniToOno,
                        ),
                      ),
                      const SizedBox(height: Insets.huge),
                      naStred(
                        SectionLabel('ZAKÁZKY (${vozidlo.zakazky.length})'),
                      ),
                      const SizedBox(height: Insets.sm),
                      if (vozidlo.zakazky.isEmpty)
                        naStred(
                          const _Prazdne(
                            'Vůz u nás zatím nemá žádnou zakázku.',
                          ),
                        )
                      else
                        for (final zakazka in vozidlo.zakazky) ...[
                          naStred(
                            OrderCard(
                              order: zakazka,
                              onTap: () async {
                                await onOpenOrder(zakazka);
                                ref.invalidate(kartaVozidlaProvider(vozidloId));
                              },
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                        ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Hlavicka extends StatelessWidget {
  const _Hlavicka({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isIOS = context.isIOS;

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.base,
        MediaQuery.paddingOf(context).top + Insets.base,
        Insets.xxl,
        Insets.lg,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zpět',
            onPressed: onBack,
            icon: Icon(
              isIOS
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: Insets.xxs),
          Expanded(
            child: Text(
              'Vyhledat vozidlo',
              style: AppTextStyles.appBarTitle(
                isIOS: isIOS,
              ).copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Prazdne extends StatelessWidget {
  const _Prazdne(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      child: Text(
        text,
        style: AppTextStyles.cardBody.copyWith(color: context.palette.muted),
      ),
    );
  }
}

class _Sdeleni extends StatelessWidget {
  const _Sdeleni(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: palette.muted),
            const SizedBox(height: Insets.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
