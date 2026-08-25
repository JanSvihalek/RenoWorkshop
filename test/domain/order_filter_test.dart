import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/branch.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_filter.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_status.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/service_order.dart';

ServiceOrder order({
  required String id,
  required OrderStatus status,
  required Branch branch,
  String licensePlate = '1AA 1111',
  String customerName = 'Petr Novák',
  String? mechanicName = 'Jan Dvořák',
  DateTime? dueAt,
}) {
  return ServiceOrder(
    id: id,
    licensePlate: licensePlate,
    model: 'BMW 320d',
    customerName: customerName,
    status: status,
    branch: branch,
    receivedAt: DateTime(2026, 8, 20, 8),
    dueAt: dueAt ?? DateTime(2026, 8, 26, 15),
    vin: 'WBATEST0000000001',
    mechanicName: mechanicName,
  );
}

void main() {
  final orders = [
    order(id: 'A', status: OrderStatus.inRepair, branch: Branch.brno,
        dueAt: DateTime(2026, 8, 28)),
    order(id: 'B', status: OrderStatus.pickedUp, branch: Branch.praha,
        licensePlate: '2BB 2222', dueAt: DateTime(2026, 8, 22)),
    order(id: 'C', status: OrderStatus.inRepair, branch: Branch.praha,
        customerName: 'Lucie Marková', mechanicName: 'Petra Válková',
        dueAt: DateTime(2026, 8, 24)),
  ];

  group('OrderFilter', () {
    test('bez filtrů vrátí vše seřazené podle termínu', () {
      final result = const OrderFilter().apply(orders);

      expect(result.map((o) => o.id), ['B', 'C', 'A']);
    });

    test('filtry se skládají (pobočka AND stav)', () {
      const filter = OrderFilter(
        branch: Branch.praha,
        status: OrderStatus.inRepair,
      );

      expect(filter.apply(orders).map((o) => o.id), ['C']);
    });

    test('hledá napříč SPZ, zákazníkem a číslem zakázky', () {
      expect(
        const OrderFilter(query: 'marková').apply(orders).map((o) => o.id),
        ['C'],
      );
      expect(
        const OrderFilter(query: '2bb').apply(orders).map((o) => o.id),
        ['B'],
      );
    });

    test('filtr mechanika vybere jen jeho zakázky', () {
      const filter = OrderFilter(mechanicName: 'Petra Válková');

      expect(filter.apply(orders).map((o) => o.id), ['C']);
    });

    test('includeClosed=false skryje vyzvednuté zakázky', () {
      const filter = OrderFilter(includeClosed: false);

      expect(filter.apply(orders).map((o) => o.id), ['C', 'A']);
    });

    test('řazení podle stavu respektuje pořadí kroků na dílně', () {
      const filter = OrderFilter(sort: OrderSort.status);

      expect(filter.apply(orders).map((o) => o.id), ['A', 'C', 'B']);
    });

    test('activeCount počítá jen skutečně aktivní filtry', () {
      expect(const OrderFilter().activeCount, 0);
      expect(const OrderFilter(query: '   ').activeCount, 0);
      expect(
        const OrderFilter(branch: Branch.brno, query: 'x').activeCount,
        2,
      );
    });

    test('prázdný výsledek je prázdný seznam, ne chyba', () {
      const filter = OrderFilter(branch: Branch.zlin);

      expect(filter.apply(orders), isEmpty);
    });
  });

  group('ServiceOrder', () {
    test('isOverdue platí jen pro nedokončené zakázky', () {
      final now = DateTime(2026, 8, 25, 10);

      expect(
        order(id: 'X', status: OrderStatus.inRepair, branch: Branch.brno,
                dueAt: DateTime(2026, 8, 24))
            .isOverdue(now: now),
        isTrue,
      );
      expect(
        order(id: 'Y', status: OrderStatus.readyForPickup, branch: Branch.brno,
                dueAt: DateTime(2026, 8, 24))
            .isOverdue(now: now),
        isFalse,
      );
    });

    test('iniciály mechanika, nepřiřazená zakázka má otazník', () {
      expect(
        order(id: 'X', status: OrderStatus.received, branch: Branch.brno)
            .mechanicInitials,
        'JD',
      );
      expect(
        order(id: 'Y', status: OrderStatus.received, branch: Branch.brno,
                mechanicName: null)
            .mechanicInitials,
        '?',
      );
    });
  });

  group('OrderStatus', () {
    test('next posouvá o jeden krok a na konci vrací null', () {
      expect(OrderStatus.received.next, OrderStatus.diagnostics);
      expect(OrderStatus.pickedUp.next, isNull);
    });

    test('apiValue je stabilní klíč pro serializaci', () {
      for (final status in OrderStatus.values) {
        expect(OrderStatus.fromApiValue(status.apiValue), status);
      }
    });
  });
}
