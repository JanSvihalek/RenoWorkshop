import '../../orders/domain/entities/plan_klempirny.dart';
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
}
