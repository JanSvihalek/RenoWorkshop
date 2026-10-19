import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../akce/presentation/akce_providers.dart';
import '../../orders/domain/entities/order_filter.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../data/plan_data_source.dart';
import '../domain/prehled_planu.dart';

/// Plán čte tatáž služba jako zakázky.
final planDataSourceProvider = Provider<PlanDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is PlanDataSource) return zdroj as PlanDataSource;
  throw StateError(
    'Zdroj dat ${zdroj.runtimeType} neumí plán klempírny (PlanDataSource).',
  );
});

/// Kolik týdnů plán ukazuje - týden, nebo 14 dní.
final planTydnuProvider = StateProvider<int>((ref) => 1);

/// Pondělí prvního zobrazeného týdne. Začíná se tímto týdnem.
final planZacatekProvider = StateProvider<DateTime>(
  (ref) => pondeli(ref.watch(dnesProvider)),
);

/// Vybraná pobočka (druhá číslice útvaru). `null` = první z nabídky.
final planPobockaProvider = StateProvider<String?>((ref) => null);

/// Filtr plánu - stejný jako u seznamu zakázek (hledání, útvar, pořadač,
/// stavy, zodpovídá, zpracovává). Pobočku vybírají čipy nahoře.
final planFiltrProvider = StateProvider<OrderFilter>(
  (ref) => const OrderFilter(),
);

/// Jen zakázky s tímto kódem laku (ručním i z barvy vozu).
final planKodLakuProvider = StateProvider<String?>((ref) => null);

/// Naplánováno / Hotovo / Bez plánu.
final planStavPlanuProvider = StateProvider<StavPlanuFiltr?>((ref) => null);

/// Plán na zobrazené týdny, včetně víkendů - blok přes víkend se tak
/// neztratí.
final planKlempirnyProvider = FutureProvider<PrehledPlanu>((ref) {
  final zacatek = ref.watch(planZacatekProvider);
  final tydnu = ref.watch(planTydnuProvider);
  final konec = DateTime(
    zacatek.year,
    zacatek.month,
    zacatek.day + tydnu * 7 - 1,
  );
  return ref.watch(planDataSourceProvider).nactiPlan(zacatek, konec);
});
