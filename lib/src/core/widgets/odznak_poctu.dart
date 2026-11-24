import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Číslo v rohu ikony v navigaci - třeba zakázky s novou změnou od
/// kolegů. Nula = bez odznaku, nad 99 „99+".
class OdznakPoctu extends StatelessWidget {
  const OdznakPoctu({super.key, required this.pocet, required this.child});

  final int pocet;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      key: pocet > 0 ? const Key('nav-pocet-zmen') : null,
      isLabelVisible: pocet > 0,
      backgroundColor: AppColors.accent,
      textColor: Colors.white,
      label: Text(pocet > 99 ? '99+' : '$pocet'),
      child: child,
    );
  }
}
