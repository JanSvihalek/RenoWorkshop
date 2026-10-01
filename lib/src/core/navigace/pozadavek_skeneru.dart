import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/domain/entities/nastaveni.dart';
import '../../features/settings/presentation/controllers/nastaveni_controller.dart';
import '../widgets/workshop_bottom_nav.dart';

/// Záložka, která má po otevření sama spustit skener, nebo `null`.
///
/// Nastaví ji navigace při klepnutí na Příjem nebo Vozidla (když to má
/// technik v nastavení zapnuté); obrazovka si ho vyzvedne a hned zahodí,
/// takže po návratu ze skeneru ani po přepnutí zpět se znovu nespustí.
///
/// Výchozí hodnota platí pro start aplikace: otevírá-li se rovnou na
/// Příjmu nebo Vozidlech, skener se spustí stejně jako po klepnutí na
/// záložku. Čte se poprvé až v té obrazovce, tedy po přihlášení.
final pozadavekSkeneruProvider = StateProvider<WorkshopTab?>((ref) {
  final nastaveni = ref.read(nastaveniProvider);
  if (!nastaveni.skenovatPoOtevreni) return null;
  return switch (nastaveni.uvodniZalozka) {
    UvodniZalozka.prijem => WorkshopTab.prijem,
    UvodniZalozka.vozidla => WorkshopTab.vyhledavani,
    UvodniZalozka.zakazky => null,
  };
});

/// Technik ve skeneru klepl na „Zadat ručně" - záložka, ze které skener
/// otevřel, si má po jeho zavření vzít do pole kurzor a vyvolat klávesnici.
final zadatRucneProvider = StateProvider<WorkshopTab?>((ref) => null);
