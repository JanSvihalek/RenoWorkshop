import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/orders/presentation/controllers/orders_providers.dart';
import '../../features/settings/presentation/controllers/nastaveni_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';

/// Žlutý pruh pod obsahem, dokud jsou zapnutá ukázková data.
///
/// Ukázkové zakázky vypadají stejně jako ostré. Bez pruhu by technik po
/// návratu do firmy mohl hledat vůz, který v ukázce není, nebo zapsat
/// poznámku, která se nikam neuloží.
///
/// Jen když si je zapnul sám - build bez služby nemá co vypnout.
class UkazkovaDataPruh extends ConsumerWidget {
  const UkazkovaDataPruh({super.key, this.dolniOkraj = true});

  /// Odsadit od spodního okraje obrazovky. Na telefonu je pod pruhem
  /// ještě navigační lišta, která okraj drží sama.
  final bool dolniOkraj;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zapnuto =
        ref.watch(buildSeSluzbouProvider) &&
        ref.watch(nastaveniProvider.select((n) => n.ukazkovaData));
    if (!zapnuto) return const SizedBox.shrink();

    return Material(
      key: const Key('ukazkova-data-pruh'),
      color: AppColors.ukazkovaData,
      child: SafeArea(
        top: false,
        bottom: dolniOkraj,
        child: Padding(
          padding: const EdgeInsets.only(left: Insets.xxl, right: Insets.sm),
          child: Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 16,
                color: AppColors.ink,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'Ukázková data – nejsou z Heliosu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metaSmall.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const Key('vypnout-ukazkova-data'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => ref
                    .read(nastaveniProvider.notifier)
                    .zmenUkazkovaData(false),
                child: const Text('Vypnout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
