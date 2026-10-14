import '../domain/technicka_kampan.dart';

/// Technické kampaně. Implementuje ho stejná služba jako zakázky
/// (REST, ukázková data, testy) - viz `kampaneDataSourceProvider`.
abstract interface class KampaneDataSource {
  /// `GET /technical-campaigns` - všechny kampaně s počtem vozidel.
  Future<PrehledKampani> nactiKampane();

  /// `GET /technical-campaigns/{id}/vins` - VINy kampaně (k úpravě).
  Future<List<String>> nactiVinyKampane(String id);

  /// `POST /technical-campaigns` (kampaň bez id) nebo `PUT …/{id}`.
  /// Seznam VINů se nahradí celý. Jen správce akcí, jinak
  /// [ServiceOrderException] s hláškou.
  Future<TechnickaKampan> ulozKampan(TechnickaKampan kampan, List<String> viny);

  /// `DELETE /technical-campaigns/{id}` - jen správce akcí.
  Future<void> smazKampan(String id);
}
