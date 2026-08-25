import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/mock_service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/branch.dart';
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
    expect(orders.map((order) => order.branch).toSet(), Branch.values.toSet());
    expect(
      orders.map((order) => order.status).toSet(),
      OrderStatus.values.toSet(),
    );
    expect(orders.map((order) => order.id).toSet(), hasLength(orders.length));
  });

  test('mutace se drží v paměti mezi voláními', () async {
    final dataSource = MockServiceOrderDataSource(latency: Duration.zero);
    final first = (await dataSource.fetchOrders()).first;

    await dataSource.updateStatus(first.id, OrderStatus.pickedUp.apiValue);
    final reloaded = await dataSource.fetchOrder(first.id);

    expect(reloaded!.status, OrderStatus.pickedUp.apiValue);
  });
}
