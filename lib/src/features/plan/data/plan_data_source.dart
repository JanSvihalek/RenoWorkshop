import '../../orders/domain/entities/plan_klempirny.dart';
import '../domain/kapacita.dart';
import '../domain/prehled_planu.dart';

/// Plán klempírny. Implementuje ho stejná služba jako zakázky (REST,
/// ukázková data, testy) - viz `planDataSourceProvider`. Zápis úkonů
/// jde přes zakázku (`ServiceOrderDataSource.pridejUkonPlanu`), ať se
/// propíše i do detailu.
abstract interface class PlanDataSource {
  /// `GET /bodyshop-plan?from=&to=` - bloky, které se s obdobím překrývají.
  Future<PrehledPlanu> nactiPlan(DateTime od, DateTime do_);

  /// `GET /bodyshop-plan/types` - typy úkonů do nabídky.
  Future<List<TypUkonu>> nactiTypyUkonu();

  /// `GET /bodyshop-plan/capacity` - lidé a ruční dny, jen s právem Kapacita.
  Future<PrehledKapacity> nactiKapacitu(String pobocka);

  /// Přeřadí člověka: kód dílny, `mimo`, nebo `null` zpět podle tarifu.
  Future<void> zaradCloveka(int id, String? dilna);

  Future<void> pridejNepritomnost(int id, DateTime od, DateTime do_);

  Future<void> smazNepritomnost(int id);

  /// Ručně zadaná kapacita dne; `null` vrátí den na počet lidí.
  Future<void> ulozKapacituDne(
    String pobocka,
    DateTime den,
    Dilna dilna,
    int? aw,
  );
}
