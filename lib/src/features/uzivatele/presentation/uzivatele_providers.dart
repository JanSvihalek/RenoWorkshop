import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/presentation/controllers/orders_providers.dart';
import '../data/uzivatele_data_source.dart';
import '../domain/uzivatele.dart';

/// Správu uživatelů obsluhuje tatáž služba jako zakázky.
final uzivateleDataSourceProvider = Provider<UzivateleDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is UzivateleDataSource) return zdroj as UzivateleDataSource;
  throw StateError('Zdroj dat ${zdroj.runtimeType} neumí správu uživatelů.');
});

/// Uživatelé a pořadače - jen pro admina (služba jinak odmítne).
final prehledUzivateluProvider = FutureProvider<PrehledUzivatelu>(
  (ref) => ref.watch(uzivateleDataSourceProvider).nactiUzivatele(),
);

/// Uloží roli a práva uživatele a načte přehled znovu. Změna vlastních
/// práv se projeví i v appce (štítek Jen čtení, akce).
Future<void> ulozUzivatele(WidgetRef ref, UzivatelSpravy uzivatel) async {
  await ref
      .read(uzivateleDataSourceProvider)
      .ulozUzivatele(
        uzivatel.email,
        role: uzivatel.role,
        prava: uzivatel.prava,
      );
  ref.invalidate(prehledUzivateluProvider);
  ref.invalidate(mojePravaProvider);
}
