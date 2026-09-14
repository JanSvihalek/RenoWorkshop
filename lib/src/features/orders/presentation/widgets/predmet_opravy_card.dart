import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import 'detail_cards.dart';

/// Předmět opravy v detailu zakázky - co se na voze opravuje.
///
/// Stojí nahoře, hned pod daty: na klempírně je to první, co člověk
/// o zakázce potřebuje vědět, a dosud to hledal v Excelu.
class PredmetOpravyCard extends StatelessWidget {
  const PredmetOpravyCard({
    super.key,
    required this.predmet,
    required this.onUpravit,
  });

  final String? predmet;
  final VoidCallback onUpravit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = predmet;

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('PŘEDMĚT OPRAVY')),
              Semantics(
                button: true,
                label: text == null
                    ? 'Zapsat předmět opravy'
                    : 'Upravit předmět opravy',
                child: GestureDetector(
                  onTap: onUpravit,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      text == null ? 'Zapsat' : 'Upravit',
                      style: AppTextStyles.chip.copyWith(
                        fontSize: 13,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.base),
          Text(
            text ?? 'Zatím nezapsáno.',
            style: AppTextStyles.cardBody.copyWith(
              color: text == null ? palette.muted : palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulář pro předmět opravy. Vrací nový text (i prázdný = smazat),
/// nebo `null`, když se úprava zrušila.
Future<String?> upravPredmetOpravy(BuildContext context, String? puvodni) {
  final pole = TextEditingController(text: puvodni ?? '');

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: const Text('Předmět opravy'),
      content: TextField(
        controller: pole,
        autofocus: true,
        maxLines: 5,
        minLines: 2,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Např. zadní nárazník, víko kufru, levé zadní světlo',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(pole.text.trim()),
          child: const Text('Uložit'),
        ),
      ],
    ),
  );
}
