import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/orders_providers.dart';
import '../widgets/order_card.dart';

/// Hledání v archivu.
///
/// Seznam na hlavní obrazovce drží jen dílnu za poslední měsíce. Tahle
/// obrazovka se ptá serveru a najde i zakázku starou rok - typicky když
/// se někdo potřebuje vrátit k fotodokumentaci nebo poznámkám.
class ArchivScreen extends ConsumerWidget {
  const ArchivScreen({
    super.key,
    required this.dotaz,
    required this.onOpenOrder,
    required this.onBack,
  });

  final String dotaz;
  final void Function(ServiceOrder order) onOpenOrder;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vysledek = ref.watch(archivProvider(dotaz));

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _Header(dotaz: dotaz, onBack: onBack),
          Expanded(
            child: vysledek.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (chyba, _) => _Sdeleni(
                ikona: Icons.cloud_off_rounded,
                titulek: 'Hledání se nezdařilo',
                text: '$chyba',
              ),
              data: (zakazky) => zakazky.isEmpty
                  ? const _Sdeleni(
                      ikona: Icons.search_off_rounded,
                      titulek: 'Nic se nenašlo',
                      text:
                          'Zkuste jinou SPZ, číslo zakázky nebo VIN. '
                          'Hledá se i mezi uzavřenými zakázkami.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.xl,
                        Insets.lg,
                        Insets.xl,
                        Insets.giant,
                      ),
                      itemCount: zakazky.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Insets.md),
                      itemBuilder: (_, index) => OrderCard(
                        order: zakazky[index],
                        onTap: () => onOpenOrder(zakazky[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dotaz, required this.onBack});

  final String dotaz;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.base,
        topInset + Insets.base,
        Insets.xxl,
        Insets.xl,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              context.isIOS
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: Insets.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archiv',
                  style: AppTextStyles.appBarTitle(
                    isIOS: context.isIOS,
                  ).copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  dotaz,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.monoLabel.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sdeleni extends StatelessWidget {
  const _Sdeleni({
    required this.ikona,
    required this.titulek,
    required this.text,
  });

  final IconData ikona;
  final String titulek;
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
            Icon(ikona, size: 44, color: palette.muted),
            const SizedBox(height: Insets.lg),
            Text(
              titulek,
              style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
            ),
            const SizedBox(height: Insets.sm),
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
