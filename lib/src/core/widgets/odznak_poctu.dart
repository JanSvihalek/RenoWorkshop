import 'package:flutter/material.dart';

import '../theme/barvy_zmen.dart';

/// Číslo v rohu ikony v navigaci - změněné zakázky (barvy změn).
/// Nula = bez odznaku, nad 99 „99+".
class OdznakPoctu extends StatelessWidget {
  const OdznakPoctu({super.key, required this.pocet, required this.child});

  final int pocet;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      key: pocet > 0 ? const Key('nav-pocet-zmen') : null,
      isLabelVisible: pocet > 0,
      backgroundColor: context.barvyZmen.akcent,
      textColor: context.barvyZmen.tooltipText,
      label: Text(pocet > 99 ? '99+' : '$pocet'),
      child: child,
    );
  }
}
