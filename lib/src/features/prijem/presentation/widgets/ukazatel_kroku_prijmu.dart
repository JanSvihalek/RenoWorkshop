import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';

/// „Krok 1 ze 4 · Identifikace vozidla" a čtyři dílky postupu - v hlavičce
/// hledání i v průvodci, ať je vidět, že jde o jeden postup.
class UkazatelKrokuPrijmu extends StatelessWidget {
  const UkazatelKrokuPrijmu({
    super.key,
    required this.cislo,
    required this.nazev,
    this.naTmavem = false,
    this.textKey,
  });

  /// Celkem kroků: identifikace, fotodokumentace, kontrola, souhrn.
  static const celkem = 4;

  final int cislo;
  final String nazev;
  final bool naTmavem;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = naTmavem ? Colors.white70 : AppColors.accent;
    final neaktivni = naTmavem ? Colors.white24 : palette.hairline;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Krok $cislo ze $celkem · $nazev',
            key: textKey,
            style: AppTextStyles.metaSmall.copyWith(
              color: text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        for (var i = 1; i <= celkem; i++) ...[
          Container(
            width: 26,
            height: 4,
            decoration: BoxDecoration(
              color: i <= cislo ? AppColors.accent : neaktivni,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (i < celkem) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
