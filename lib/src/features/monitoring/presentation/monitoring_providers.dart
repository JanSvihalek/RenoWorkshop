import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/presentation/controllers/orders_providers.dart';
import '../domain/logy.dart';
import '../domain/monitoring.dart';

/// Monitoring obsluhuje tatáž služba jako zakázky.
final monitoringDataSourceProvider = Provider<MonitoringDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is MonitoringDataSource) return zdroj as MonitoringDataSource;
  throw StateError('Zdroj dat ${zdroj.runtimeType} neumí monitoring.');
});

/// Vybrané období ve dnech (Dnes / 7 / 30 / 90).
final obdobiMonitoringuProvider = StateProvider<int>((ref) => 7);

/// Souhrn za období - jen pro admina (služba jinak odmítne).
final monitoringProvider = FutureProvider.family<PrehledMonitoringu, int>(
  (ref, dni) => ref.watch(monitoringDataSourceProvider).nactiMonitoring(dni),
);

/// Časová osa jednoho uživatele.
final osaMonitoringuProvider =
    FutureProvider.family<OsaMonitoringu, ({String email, int dni})>(
      (ref, k) => ref
          .watch(monitoringDataSourceProvider)
          .nactiOsuMonitoringu(k.email, k.dni),
    );

/// Log přístupů a událostí obsluhuje tatáž služba jako zakázky.
final logyDataSourceProvider = Provider<LogyDataSource>((ref) {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (zdroj is LogyDataSource) return zdroj as LogyDataSource;
  throw StateError('Zdroj dat ${zdroj.runtimeType} neumí logy.');
});

/// Uživatelé a názvy událostí do filtru logů.
final volbyLoguProvider = FutureProvider<VolbyLogu>(
  (ref) => ref.watch(logyDataSourceProvider).nactiVolbyLogu(),
);
