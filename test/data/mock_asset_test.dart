import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/mock_service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_status.dart';

/// Hlídá, že mock data v assetu jdou načíst a pokrývají všechny pobočky
/// i stavy - bez toho by se UI nedalo pořádně proklikat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock asset se načte a pokrývá pobočky i stavy', () async {
    final dataSource = MockServiceOrderDataSource(latency: Duration.zero);

    final orders = (await dataSource.fetchOrders())
        .map((dto) => dto.toDomain())
        .toList();

    expect(orders.length, greaterThanOrEqualTo(10));
    // Pobočky nejsou pevný výčet, ale v mock datech mají být všechny,
    // ať jde proklikat filtrování.
    final pobocky = orders
        .map((order) => order.branch?.label)
        .whereType<String>()
        .toSet();
    // Bubeneč mezi servisními útvary není - žádný kód nemá druhou
    // číslici 5, takže se v datech objevit nemůže.
    expect(pobocky, {'Brno', 'Čestlice', 'Kongresové Centrum', 'Česká'});
    // Zakázka bez útvaru tam musí zůstat - testuje NULL z Heliosu.
    expect(orders.any((order) => order.branch == null), isTrue);
    expect(
      orders.map((order) => order.status).toSet(),
      OrderStatus.values.toSet(),
    );
    expect(orders.map((order) => order.id).toSet(), hasLength(orders.length));
  });

  /// Skener hledá VIN podle tvaru: přesně 17 znaků a bez I, O a Q, které
  /// si navíc opravuje na 1 a 0. Kdyby měl mock jiný tvar, dal by se
  /// naskenovaný VIN v ukázkových datech těžko dohledat a vypadalo by to
  /// jako chyba skeneru.
  test('VIN v mock datech má skutečný tvar', () async {
    final dataSource = MockServiceOrderDataSource(latency: Duration.zero);

    final viny = (await dataSource.fetchOrders())
        .map((dto) => dto.vin)
        .where((vin) => vin.isNotEmpty)
        .toList();

    expect(viny, isNotEmpty);
    for (final vin in viny) {
      expect(vin, matches(RegExp(r'^[A-HJ-NPR-Z0-9]{17}$')), reason: vin);
    }
    expect(viny.toSet(), hasLength(viny.length));
  });

  test('naskenovaný kód se dá v mock datech dohledat', () async {
    final dataSource = MockServiceOrderDataSource(latency: Duration.zero);
    final zakazka = (await dataSource.fetchOrders()).first;

    final podleVin = await dataSource.searchOrders(zakazka.vin);
    final podleSpz = await dataSource.searchOrders(zakazka.licensePlate);

    expect(podleVin.map((dto) => dto.id), contains(zakazka.id));
    expect(podleSpz.map((dto) => dto.id), contains(zakazka.id));
  });

  test('mutace se drží v paměti mezi voláními', () async {
    final dataSource = MockServiceOrderDataSource(latency: Duration.zero);
    final first = (await dataSource.fetchOrders()).first;

    await dataSource.updateStatus(first.id, OrderStatus.pickedUp.apiValue);
    final reloaded = await dataSource.fetchOrder(first.id);

    expect(reloaded!.status, OrderStatus.pickedUp.apiValue);
  });
}
