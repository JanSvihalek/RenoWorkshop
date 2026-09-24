import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../layout/rozlozeni.dart';
import '../navigace/pozadavek_skeneru.dart';
import '../../features/prijem/presentation/controllers/prijem_providers.dart';
import '../../features/settings/presentation/controllers/nastaveni_controller.dart';
import '../../features/vozidla/presentation/controllers/vozidla_providers.dart';
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

  /// Přepnutí záložky. Příjem i Vozidla začínají SPZ, takže se na nich
  /// rovnou nabídne skener - jen při klepnutí na záložku, ne při návratu
  /// z detailu nebo ze samotného skeneru.
  ///
  /// Hledání na Příjmu a Vozidlech se klepnutím na záložku vymaže - kdo
  /// se na ni vrací, jde na další vůz a starý výsledek by jen mátl.
  /// Musí to být dřív než požadavek na skener: s rozepsaným hledáním se
  /// skener sám neotvírá.
  void _prepni(WidgetRef ref, int index) {
    final tab = WorkshopTab.values[index];
    switch (tab) {
      case WorkshopTab.prijem:
        ref.read(otevritJedinyPrijemProvider.notifier).state = false;
        ref.read(dotazPrijmuProvider.notifier).state = '';
      case WorkshopTab.vyhledavani:
        ref.read(otevritJedineVozidloProvider.notifier).state = false;
        ref.read(dotazVozidlaProvider.notifier).state = '';
      default:
    }
    final skenovat =
        ref.read(nastaveniProvider).skenovatPoOtevreni &&
        (tab == WorkshopTab.prijem || tab == WorkshopTab.vyhledavani);
    ref.read(pozadavekSkeneruProvider.notifier).state = skenovat ? tab : null;

    navigationShell.goBranch(
      index,
      // Druhé kliknutí na už otevřenou záložku ji vrátí na začátek.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

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
              onSelect: (tab) => _prepni(ref, tab.index),
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
        onSelect: (tab) => _prepni(ref, tab.index),
      ),
    );
  }
}
