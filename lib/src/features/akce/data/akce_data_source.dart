import '../domain/marketingova_akce.dart';

/// Marketingové akce. Implementuje ho stejná služba jako zakázky
/// (REST, ukázková data, testy) - viz `akceDataSourceProvider`.
abstract interface class AkceDataSource {
  /// `GET /campaigns` - akce, které ještě neskončily.
  Future<PrehledAkci> nactiAkce();

  /// `POST /campaigns` (akce bez id) nebo `PUT /campaigns/{id}`.
  /// Jen správce akcí, jinak [ServiceOrderException] s hláškou.
  Future<MarketingovaAkce> ulozAkci(MarketingovaAkce akce);

  /// `DELETE /campaigns/{id}` - jen správce akcí.
  Future<void> smazAkci(String id);
}
