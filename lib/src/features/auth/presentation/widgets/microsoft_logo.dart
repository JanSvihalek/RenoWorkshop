import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_colors.dart';

/// Logo Microsoftu dle brand guidelines - čtyři barevné čtverce.
class MicrosoftLogo extends StatelessWidget {
  const MicrosoftLogo({super.key, this.squareSize = 8, this.gap = 2});

  final double squareSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    Widget square(Color color) => SizedBox(
      width: squareSize,
      height: squareSize,
      child: ColoredBox(color: color),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            square(AppColors.msRed),
            SizedBox(width: gap),
            square(AppColors.msGreen),
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            square(AppColors.msBlue),
            SizedBox(width: gap),
            square(AppColors.msYellow),
          ],
        ),
      ],
    );
  }
}
