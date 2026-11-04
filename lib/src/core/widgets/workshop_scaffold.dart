import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../layout/rozlozeni.dart';
import '../../features/orders/presentation/controllers/orders_providers.dart';
import '../../features/plan/presentation/prepinac_aplikaci.dart';
import 'ukazkova_data_pruh.dart';
import 'workshop_bottom_nav.dart';
import 'workshop_side_nav.dart';

/// Rám appky: navigace kolem obsahu, který se v ní přepíná.
///
/// Navigace je nad obrazovkami, ne v nich - při přepnutí záložky se tak
/// nepřekresluje celá obrazovka, jen obsah uvnitř. Každá záložka si přitom
/// drží svůj stav (posun seznamu, filtry zakázek), protože záložky
/// nejsou zanoření: člověk se mezi nimi přepíná tam a zpět.
class WorkshopScaffold extends ConsumerWidget {
  const WorkshopScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Přepnutí záložky.
  void _prepni(int index) {
    navigationShell.goBranch(
      index,
      // Druhé kliknutí na už otevřenou záložku ji vrátí na začátek.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktivni = WorkshopTab.values[navigationShell.currentIndex];
    // Záložka Admin jen pro admina (práva z /me).
    final admin = ref.watch(mojePravaProvider).valueOrNull?.jeAdmin ?? false;

    // Na tabletu je obrazovka na šířku a spodní lišta by ukrajovala
    // z výšky, které je málo - navigace jde do svislého pruhu vlevo.
    if (context.jeTablet) {
      return Scaffold(
        body: Row(
          children: [
            WorkshopSideNav(
              active: aktivni,
              onSelect: (tab) => _prepni(tab.index),
              onAplikace: () => zobrazPrepinacAplikaci(context, ref),
              zobrazitAdmin: admin,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: navigationShell),
                  const UkazkovaDataPruh(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nad lištou - spodní okraj obrazovky drží lišta.
          const UkazkovaDataPruh(dolniOkraj: false),
          WorkshopBottomNav(
            active: aktivni,
            onSelect: (tab) => _prepni(tab.index),
            zobrazitAdmin: admin,
          ),
        ],
      ),
    );
  }
}
