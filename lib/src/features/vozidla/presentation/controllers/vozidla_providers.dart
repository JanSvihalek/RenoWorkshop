import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../orders/domain/repositories/service_order_repository.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../data/vozidla_data_source.dart';
import '../../domain/entities/vozidlo.dart';

/// Zdroj vozidel je tentýž jako zdroj zakázek - obě data vrací stejná
/// služba. Když ho někdo nahradí zdrojem, který vozidla neumí (starý fake
/// v testu), dozví se to tady, ne až pádem uprostřed obrazovky.
final vozidlaDataSourceProvider = Provider<VozidlaDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is VozidlaDataSource) return zdroj as VozidlaDataSource;
  throw StateError(
    'Zdroj dat ${zdroj.runtimeType} neumí vozidla (VozidlaDataSource).',
  );
});

/// Nejkratší dotaz, se kterým se ptáme serveru. Server kratší odmítne
/// a z dvou znaků SPZ by se stejně vrátilo cokoli.
const nejkratsiDotazVozidla = 3;

/// Co se hledá. Drží se mimo obrazovku, ať ho může vyplnit skener
/// a ať přepnutí záložky nezahodí rozepsanou SPZ.
final dotazVozidlaProvider = StateProvider<String>((ref) => '');

/// Dotaz přišel ze skeneru: jediný výsledek se má rovnou otevřít.
///
/// U psaní rukou schválně ne - při psaní `2BK` by karta vyskočila dřív,
/// než člověk dopíše, a zase by se musel vracet.
final otevritJedineVozidloProvider = StateProvider<bool>((ref) => false);

/// Vozidlo otevřené v pravém sloupci na tabletu.
final vybraneVozidloProvider = StateProvider<int?>((ref) => null);

final hledaniVozidelProvider = FutureProvider.autoDispose
    .family<List<NalezeneVozidlo>, String>((ref, dotaz) async {
      final ocisteny = dotaz.trim();
      if (ocisteny.length < nejkratsiDotazVozidla) return const [];
      try {
        return await ref
            .watch(vozidlaDataSourceProvider)
            .hledejVozidla(ocisteny);
      } on ServiceOrderException {
        rethrow;
      } catch (chyba) {
        throw ServiceOrderException('Hledání vozidla se nezdařilo: $chyba');
      }
    });

final kartaVozidlaProvider = FutureProvider.autoDispose
    .family<KartaVozidla?, int>((ref, id) async {
      try {
        return await ref.watch(vozidlaDataSourceProvider).kartaVozidla(id);
      } on ServiceOrderException {
        rethrow;
      } catch (chyba) {
        throw ServiceOrderException(
          'Kartu vozidla se nepodařilo načíst: $chyba',
        );
      }
    });
