import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/workshop_bottom_nav.dart';

/// Záložka, která má po otevření sama spustit skener, nebo `null`.
///
/// Nastaví ji navigace při klepnutí na Příjem nebo Vozidla (když to má
/// technik v nastavení zapnuté); obrazovka si ho vyzvedne a hned zahodí,
/// takže po návratu ze skeneru ani po přepnutí zpět se znovu nespustí.
final pozadavekSkeneruProvider = StateProvider<WorkshopTab?>((ref) => null);

/// Technik ve skeneru klepl na „Zadat ručně" - záložka, ze které skener
/// otevřel, si má po jeho zavření vzít do pole kurzor a vyvolat klávesnici.
final zadatRucneProvider = StateProvider<WorkshopTab?>((ref) => null);
