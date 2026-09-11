import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/branch.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_filter.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/dilensky_stav.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/service_order.dart';

ServiceOrder order({
  required String id,
  required String stavKod,
  required String stavNazev,
  required Branch branch,
  Department? department,
  String licensePlate = '1AA 1111',
  String customerName = 'Petr Novák',
  String? mechanicName = 'Jan Dvořák',
  DateTime? dueAt,
  DateTime? receivedAt,

  /// Helios termín u každé zakázky nemá; taková se musí umět seřadit taky.
  bool bezTerminu = false,
}) {
  return ServiceOrder(
    id: id,
    licensePlate: licensePlate,
    model: 'BMW 320d',
    customerName: customerName,
    stav: DilenskyStav(kod: stavKod, nazev: stavNazev),
    branch: branch,
    department: department,
    receivedAt: receivedAt ?? DateTime(2026, 8, 20, 8),
    dueAt: bezTerminu ? null : (dueAt ?? DateTime(2026, 8, 26, 15)),
    vin: 'WBATEST0000000001',
    mechanicName: mechanicName,
  );
}

const brno = Branch(code: '1', label: 'Brno');
const cestlice = Branch(code: '2', label: 'Čestlice');
const ceska = Branch(code: '4', label: 'Česká');

void main() {
  final orders = [
    order(
      id: 'A',
      stavKod: 'klempirna',
      stavNazev: 'Klempířské práce',
      branch: brno,
      dueAt: DateTime(2026, 8, 28),
    ),
    order(
      id: 'B',
      stavKod: 'vyzvednuto',
      stavNazev: 'Vyzvednuto',
      branch: cestlice,
      licensePlate: '2BB 2222',
      dueAt: DateTime(2026, 8, 22),
    ),
    order(
      id: 'C',
      stavKod: 'klempirna',
      stavNazev: 'Klempířské práce',
      branch: cestlice,
      customerName: 'Lucie Marková',
      mechanicName: 'Petra Válková',
      dueAt: DateTime(2026, 8, 24),
    ),
  ];

  group('OrderFilter', () {
    test('bez filtrů vrátí vše seřazené podle termínu', () {
      final result = const OrderFilter(sort: OrderSort.dueDate).apply(orders);

      expect(result.map((o) => o.id), ['B', 'C', 'A']);
    });

    test('filtry se skládají (pobočka AND stav)', () {
      const filter = OrderFilter(branchCode: '2', statusCode: 'klempirna');

      expect(filter.apply(orders).map((o) => o.id), ['C']);
    });

    test('hledá napříč SPZ, zákazníkem a číslem zakázky', () {
      expect(
        const OrderFilter(query: 'marková').apply(orders).map((o) => o.id),
        ['C'],
      );
      expect(const OrderFilter(query: '2bb').apply(orders).map((o) => o.id), [
        'B',
      ]);
    });

    test('filtr mechanika vybere jen jeho zakázky', () {
      const filter = OrderFilter(mechanicName: 'Petra Válková');

      expect(filter.apply(orders).map((o) => o.id), ['C']);
    });

    test('řazení podle stavu respektuje pořadí kroků na dílně', () {
      const filter = OrderFilter(sort: OrderSort.status);

      expect(filter.apply(orders).map((o) => o.id), ['A', 'C', 'B']);
    });

    test('activeCount počítá jen skutečně aktivní filtry', () {
      expect(const OrderFilter().activeCount, 0);
      expect(const OrderFilter(query: '   ').activeCount, 0);
      expect(const OrderFilter(branchCode: '1', query: 'x').activeCount, 2);
    });

    test('prázdný výsledek je prázdný seznam, ne chyba', () {
      const filter = OrderFilter(branchCode: '4');

      expect(filter.apply(orders), isEmpty);
    });
  });

  group('ServiceOrder', () {
    test('isOverdue se řídí termínem, ne stavem', () {
      final now = DateTime(2026, 8, 25, 10);

      expect(
        order(
          id: 'X',
          stavKod: 'klempirna',
          stavNazev: 'Klempířské práce',
          branch: brno,
          dueAt: DateTime(2026, 8, 24),
        ).isOverdue(now: now),
        isTrue,
      );
      // Dřív se hotová zakázka za opožděnou nepovažovala. Stav je nově
      // volný text z číselníku, takže z něj „hotovo" nejde poznat -
      // a vyřízená zakázka ze seznamu stejně zmizí, až ji uzavře Helios.
      expect(
        order(
          id: 'Y',
          stavKod: 'pripraveno',
          stavNazev: 'Připraveno k vyzvednutí',
          branch: brno,
          dueAt: DateTime(2026, 8, 24),
        ).isOverdue(now: now),
        isTrue,
      );
      expect(
        order(
          id: 'Z',
          stavKod: 'pripraveno',
          stavNazev: 'Připraveno k vyzvednutí',
          branch: brno,
          bezTerminu: true,
        ).isOverdue(now: now),
        isFalse,
      );
    });

    test('iniciály mechanika, nepřiřazená zakázka má otazník', () {
      expect(
        order(
          id: 'X',
          stavKod: 'prijato',
          stavNazev: 'Přijato',
          branch: brno,
        ).mechanicInitials,
        'JD',
      );
      expect(
        order(
          id: 'Y',
          stavKod: 'prijato',
          stavNazev: 'Přijato',
          branch: brno,
          mechanicName: null,
        ).mechanicInitials,
        '?',
      );
    });
  });

  group('řazení se zakázkami bez termínu', () {
    test('zakázky bez termínu jdou na konec', () {
      final zakazky = <ServiceOrder>[
        order(
          id: 'BEZ-TERMINU',
          stavKod: 'prijato',
          stavNazev: 'Přijato',
          branch: brno,
          bezTerminu: true,
        ),
        order(
          id: 'POZDEJI',
          stavKod: 'prijato',
          stavNazev: 'Přijato',
          branch: brno,
          dueAt: DateTime(2026, 8, 28),
        ),
        order(
          id: 'DRIV',
          stavKod: 'prijato',
          stavNazev: 'Přijato',
          branch: brno,
          dueAt: DateTime(2026, 8, 22),
        ),
      ];

      final serazene = const OrderFilter(
        sort: OrderSort.dueDate,
      ).apply(zakazky).map((z) => z.id);

      // Chybějící termín neznamená „nejdřív" - rozdělaná práce se známým
      // termínem má být vidět dřív.
      expect(serazene, ['DRIV', 'POZDEJI', 'BEZ-TERMINU']);
    });
  });

  test('výchozí řazení dává nejnovější zakázky nahoru', () {
    // Na klempírně se pracuje na tom, co přijelo naposled; zakázka stará
    // měsíce se nemá tlačit před dnešní příjem.
    final zakazky = <ServiceOrder>[
      order(
        id: 'STARA',
        stavKod: 'klempirna',
        stavNazev: 'Klempířské práce',
        branch: brno,
        receivedAt: DateTime(2026, 5, 4),
      ),
      order(
        id: 'NEJNOVEJSI',
        stavKod: 'klempirna',
        stavNazev: 'Klempířské práce',
        branch: brno,
        receivedAt: DateTime(2026, 8, 30),
      ),
      order(
        id: 'PROSTREDNI',
        stavKod: 'klempirna',
        stavNazev: 'Klempířské práce',
        branch: brno,
        receivedAt: DateTime(2026, 7, 15),
      ),
    ];

    final serazene = const OrderFilter().apply(zakazky).map((z) => z.id);

    expect(serazene, ['NEJNOVEJSI', 'PROSTREDNI', 'STARA']);
  });
}
