import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../layout/rozlozeni.dart';
import 'workshop_bottom_nav.dart';
import 'workshop_side_nav.dart';

/// Rám appky: navigace kolem obsahu, který se v ní přepíná.
///
/// Navigace je nad obrazovkami, ne v nich - při přepnutí záložky se tak
/// nepřekresluje celá obrazovka, jen obsah uvnitř. Každá záložka si přitom
/// drží svůj stav (posun seznamu, rozepsané hledání), protože záložky
/// nejsou zanoření: člověk se mezi nimi přepíná tam a zpět.
class WorkshopScaffold extends ConsumerWidget {
  const WorkshopScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _prepni(int index) => navigationShell.goBranch(
    index,
    // Druhé kliknutí na už otevřenou záložku ji vrátí na začátek.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktivni = WorkshopTab.values[navigationShell.currentIndex];

    // Na tabletu je obrazovka na šířku a spodní lišta by ukrajovala
    // z výšky, které je málo - navigace jde do svislého pruhu vlevo.
    if (context.jeTablet) {
      return Scaffold(
        body: Row(
          children: [
            WorkshopSideNav(
              active: aktivni,
              onSelect: (tab) => _prepni(tab.index),
              employee: ref.watch(currentEmployeeProvider),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: WorkshopBottomNav(
        active: aktivni,
        onSelect: (tab) => _prepni(tab.index),
      ),
    );
  }
}
