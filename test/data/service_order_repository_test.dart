import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/data/repositories/service_order_repository_impl.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_status.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/service_order.dart';
import 'package:renoworkshop/src/features/orders/domain/repositories/service_order_repository.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  late ServiceOrderRepositoryImpl repository;

  setUp(() {
    repository = ServiceOrderRepositoryImpl(
      FakeServiceOrderDataSource([
        buildOrderDto(id: 'ZK-1', status: 'in_repair'),
        buildOrderDto(id: 'ZK-2', status: 'picked_up', branch: 'praha'),
      ]),
    );
  });

  tearDown(() => repository.dispose());

  test('mapuje DTO na doménovou entitu', () async {
    final orders = await repository.getOrders();

    expect(orders, hasLength(2));
    expect(orders.first.status, OrderStatus.inRepair);
    expect(orders.first.receivedAt, DateTime(2026, 8, 20, 8));
  });

  test('watchOrders emituje nový seznam po posunu stavu', () async {
    final emissions = <List<ServiceOrder>>[];
    final subscription = repository.watchOrders().listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await repository.updateStatus('ZK-1', OrderStatus.qualityCheck);
    await Future<void>.delayed(Duration.zero);

    expect(emissions, hasLength(2));
    expect(emissions.last.first.status, OrderStatus.qualityCheck);
    await subscription.cancel();
  });

  test('addNote přidá poznámku na začátek seznamu', () async {
    final updated = await repository.addNote(
      orderId: 'ZK-1',
      text: 'Zkušební jízda hotová.',
      author: 'Jan Dvořák',
    );

    expect(updated.notes.first.text, 'Zkušební jízda hotová.');
    expect(updated.notes.first.author, 'Jan Dvořák');
  });

  test('neznámé ID vyhodí ServiceOrderNotFoundException', () async {
    expect(
      () => repository.updateStatus('ZK-999', OrderStatus.inRepair),
      throwsA(isA<ServiceOrderNotFoundException>()),
    );
  });
}
