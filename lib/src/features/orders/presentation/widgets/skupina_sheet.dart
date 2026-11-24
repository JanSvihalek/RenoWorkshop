import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/zpracovatel.dart';
import '../controllers/orders_providers.dart';

/// Volba z okna skupiny: [kod] skupiny, `null` = bez skupiny. Zavření
/// okna bez volby vrátí `null` celé.
typedef VolbaSkupiny = ({String? kod});

/// Okno pro výběr skupiny, která zakázku zpracovává (Příjem, Dílna).
/// Člověka (zpracovatele) nemění - ten se vybírá zvlášť.
Future<VolbaSkupiny?> vyberSkupinu(
  BuildContext context, {
  SkupinaZakazky? aktualni,
}) {
  return showModalBottomSheet<VolbaSkupiny>(
    context: context,
    builder: (context) => _SkupinaSheet(aktualni: aktualni),
  );
}

class _SkupinaSheet extends ConsumerWidget {
  const _SkupinaSheet({this.aktualni});

  final SkupinaZakazky? aktualni;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final nabidka = ref.watch(nabidkaSkupinProvider);

    Widget volba(String? kod, String nazev, {Key? key}) {
      final vybrana = aktualni?.kod == kod;
      return ListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          vybrana
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: vybrana ? AppColors.accent : palette.muted,
        ),
        title: Text(
          nazev,
          style: AppTextStyles.cardBody.copyWith(
            fontSize: 15,
            fontWeight: vybrana ? FontWeight.w600 : null,
            color: kod == null ? palette.muted2 : palette.text,
          ),
        ),
        onTap: () => Navigator.of(context).pop((kod: kod)),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.xxl,
          Insets.xl,
          Insets.xxl,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Skupina, která zakázku zpracovává',
              style: AppTextStyles.cardBody.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Kdo konkrétně na zakázce dělá, se vybírá zvlášť.',
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.md),
            ...nabidka.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Insets.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                Text(
                  'Nabídku skupin se nepodařilo načíst.',
                  style: AppTextStyles.cardBody.copyWith(color: palette.muted),
                ),
              ],
              data: (skupiny) => [
                for (final s in skupiny)
                  volba(s.kod, s.nazev, key: Key('skupina-${s.kod}')),
              ],
            ),
            if (aktualni != null)
              volba(null, 'Bez skupiny', key: const Key('skupina-zadna')),
          ],
        ),
      ),
    );
  }
}
