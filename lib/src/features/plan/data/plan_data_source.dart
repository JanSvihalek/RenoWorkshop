import '../domain/prehled_planu.dart';

/// Plán klempírny. Implementuje ho stejná služba jako zakázky (REST,
/// ukázková data, testy) - viz `planDataSourceProvider`. Zápis plánu
/// jde přes zakázku (`ServiceOrderDataSource.ulozPlanKlempirny`), ať se
/// propíše i do detailu.
abstract interface class PlanDataSource {
  /// `GET /bodyshop-plan?from=&to=` - bloky, které se s obdobím překrývají.
  Future<PrehledPlanu> nactiPlan(DateTime od, DateTime do_);
}
