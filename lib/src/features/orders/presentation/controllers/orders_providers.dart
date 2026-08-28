import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/config/app_config.dart';
import '../../data/datasources/mock_service_order_data_source.dart';
import '../../data/datasources/rest_service_order_data_source.dart';
import '../../data/datasources/service_order_data_source.dart';
import '../../data/skener_kodu.dart';
import '../../data/repositories/service_order_repository_impl.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/order_filter.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/repositories/service_order_repository.dart';

/// Zdroj dat: bez `API_BASE_URL` mock JSON, s ním reálné API.
/// Jediné místo, kde se to rozhoduje - zbytek appky rozdíl nepozná.
final serviceOrderDataSourceProvider = Provider<ServiceOrderDataSource>((ref) {
  if (!AppConfig.pouzivaApi) return MockServiceOrderDataSource();

  final dataSource = RestServiceOrderDataSource(
    baseUrl: Uri.parse(AppConfig.apiBaseUrl),
    // Token se bere až při volání, ne při sestavení - Firebase ho sám
    // obnovuje a starý by po hodině přestal platit.
    tokenProvider: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  ref.onDispose(dataSource.dispose);
  return dataSource;
});

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

/// Pobočky vyskytující se v načtených zakázkách, seřazené podle názvu.
/// Přepínač v app baru se skládá z nich, ne z pevného výčtu.
final availableBranchesProvider = Provider<List<Branch>>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  final unikatni = <String, Branch>{};
  for (final order in orders) {
    final branch = order.branch;
    if (branch != null) unikatni[branch.code] = branch;
  }
  final seznam = unikatni.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
  return seznam;
});

/// Útvary v rámci právě vybrané pobočky - jemnější filtr ve filtrovacím
/// panelu. Bez vybrané pobočky vrací útvary všechny.
final availableDepartmentsProvider = Provider<List<Department>>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  final branchCode = ref.watch(orderFilterProvider).branchCode;
  final unikatni = <String, Department>{};
  for (final order in orders) {
    if (branchCode != null && order.branch?.code != branchCode) continue;
    final department = order.department;
    if (department != null) unikatni[department.code] = department;
  }
  final seznam = unikatni.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
  return seznam;
});

/// Čtení VINu a SPZ fotoaparátem. Vlastní provider, aby šel v testech
/// nahradit bez zapojení kamery.
final skenerProvider = Provider<SkenerKodu>((ref) {
  final skener = SkenerKodu();
  ref.onDispose(skener.dispose);
  return skener;
});

/// Výsledek hledání v archivu. `family` podle hledaného textu, takže se
/// stejný dotaz nepouští dvakrát a při návratu na obrazovku je výsledek
/// hned k dispozici.
final archivProvider = FutureProvider.family<List<ServiceOrder>, String>((
  ref,
  dotaz,
) async {
  final ocisteny = dotaz.trim();
  if (ocisteny.length < 3) return const [];
  return ref.watch(serviceOrderRepositoryProvider).searchArchive(ocisteny);
});

/// Aktivní filtry seznamu.
final orderFilterProvider =
    NotifierProvider<OrderFilterController, OrderFilter>(
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

  void setBranch(String? branchCode) => state = branchCode == null
      ? state.copyWith(clearBranch: true, clearDepartment: true)
      : state.copyWith(branchCode: branchCode, clearDepartment: true);

  void setDepartment(String? departmentCode) => state = departmentCode == null
      ? state.copyWith(clearDepartment: true)
      : state.copyWith(departmentCode: departmentCode);

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
