import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock_service_order_data_source.dart';
import '../../data/datasources/service_order_data_source.dart';
import '../../data/repositories/service_order_repository_impl.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/order_filter.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/repositories/service_order_repository.dart';

/// Fáze 1: mock zdroj. Fáze 2: `RestServiceOrderDataSource(ref.watch(apiClientProvider))`.
/// Nic jiného v appce se přitom nemění.
final serviceOrderDataSourceProvider = Provider<ServiceOrderDataSource>(
  (ref) => MockServiceOrderDataSource(),
);

final serviceOrderRepositoryProvider = Provider<ServiceOrderRepository>((ref) {
  final repository = ServiceOrderRepositoryImpl(
    ref.watch(serviceOrderDataSourceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Všechny zakázky na dílně (sdílený stav, proto stream).
final ordersStreamProvider = StreamProvider<List<ServiceOrder>>(
  (ref) => ref.watch(serviceOrderRepositoryProvider).watchOrders(),
);

/// Aktivní filtry seznamu.
final orderFilterProvider = NotifierProvider<OrderFilterController, OrderFilter>(
  OrderFilterController.new,
);

/// Zakázky po aplikaci filtrů a řazení.
final filteredOrdersProvider = Provider<AsyncValue<List<ServiceOrder>>>((ref) {
  final filter = ref.watch(orderFilterProvider);
  return ref.watch(ordersStreamProvider).whenData(filter.apply);
});

/// Detail jedné zakázky. Čte ze stejného streamu jako seznam, takže posun
/// stavu v detailu se hned projeví i v seznamu.
final orderByIdProvider = Provider.family<AsyncValue<ServiceOrder?>, String>((
  ref,
  orderId,
) {
  return ref.watch(ordersStreamProvider).whenData((orders) {
    for (final order in orders) {
      if (order.id == orderId) return order;
    }
    return null;
  });
});

/// Mechanici, kterým je aktuálně přiřazená aspoň jedna zakázka (filtr).
final mechanicsProvider = Provider<List<String>>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  final names = <String>{
    for (final order in orders)
      if (order.mechanicName != null) order.mechanicName!,
  }.toList()..sort();
  return names;
});

class OrderFilterController extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => const OrderFilter();

  void setBranch(Branch? branch) => state = branch == null
      ? state.copyWith(clearBranch: true)
      : state.copyWith(branch: branch);

  void setStatus(OrderStatus? status) => state = status == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: status);

  void setMechanic(String? mechanicName) => state = mechanicName == null
      ? state.copyWith(clearMechanic: true)
      : state.copyWith(mechanicName: mechanicName);

  void setQuery(String query) => state = state.copyWith(query: query);

  void setSort(OrderSort sort) => state = state.copyWith(sort: sort);

  void setIncludeClosed(bool includeClosed) =>
      state = state.copyWith(includeClosed: includeClosed);

  void reset() => state = const OrderFilter();
}
