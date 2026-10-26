import '../domain/ulozenka_pneu.dart';

/// Uloženky pneu - implementuje je stejná služba jako zakázky.
abstract interface class UlozenkyDataSource {
  /// `GET /orders/{id}/tire-storage` - uloženky vozu zakázky.
  Future<List<UlozenkaPneu>> ulozenkyZakazky(String orderId);
}
