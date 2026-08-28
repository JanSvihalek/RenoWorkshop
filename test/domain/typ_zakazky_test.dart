import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_filter.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_status.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/service_order.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/typ_zakazky.dart';

ServiceOrder _zakazka(String id, TypZakazky? typ) => ServiceOrder(
  id: id,
  licensePlate: '1AB2345',
  model: 'BMW - 320d',
  customerName: 'Novák',
  status: OrderStatus.values.first,
  typZakazky: typ,
  receivedAt: DateTime(2026, 8, 1),
  dueAt: DateTime(2026, 8, 5),
  vin: 'WBAJN51070G980042',
);

void main() {
  group('typ zakázky z JSONu', () {
    test('vezme kód i název', () {
      final typ = TypZakazky.fromJson({'code': 'K', 'label': 'Klempířská'});

      expect(typ.kod, 'K');
      expect(typ.nazev, 'Klempířská');
    });

    test('bez názvu se ukáže aspoň kód', () {
      // Helios číselník nevyplněný - lepší kód než prázdné místo v UI.
      expect(TypZakazky.fromJson({'code': 'K', 'label': '  '}).nazev, 'K');
      expect(TypZakazky.fromJson({'code': 'K'}).nazev, 'K');
    });

    test('shoda se posuzuje podle kódu, ne podle názvu', () {
      const a = TypZakazky(kod: 'K', nazev: 'Klempířská');
      const b = TypZakazky(kod: 'K', nazev: 'Klempířské práce');

      expect(a, b);
    });
  });

  group('filtrování podle typu', () {
    final zakazky = [
      _zakazka('Z1', const TypZakazky(kod: 'B', nazev: 'Běžná')),
      _zakazka('Z2', const TypZakazky(kod: 'K', nazev: 'Klempířská')),
      _zakazka('Z3', const TypZakazky(kod: 'I', nazev: 'Interní')),
      _zakazka('Z4', null),
    ];

    test('vybere jen zakázky daného typu', () {
      const filtr = OrderFilter(typZakazkyKod: 'K');

      expect(filtr.apply(zakazky).map((z) => z.id), ['Z2']);
    });

    test('zakázka bez typu se do filtru na typ nedostane', () {
      const filtr = OrderFilter(typZakazkyKod: 'B');

      expect(filtr.apply(zakazky).map((z) => z.id), ['Z1']);
    });

    test('bez filtru projdou všechny včetně těch bez typu', () {
      const filtr = OrderFilter();

      expect(filtr.apply(zakazky), hasLength(4));
    });

    test('typ se počítá mezi aktivní filtry', () {
      const filtr = OrderFilter(typZakazkyKod: 'K');

      expect(filtr.isActive, isTrue);
      expect(filtr.activeCount, 1);
      expect(filtr.copyWith(clearTypZakazky: true).isActive, isFalse);
    });
  });

  test('posun stavu typ zakázky neztratí', () {
    final zakazka = _zakazka(
      'Z1',
      const TypZakazky(kod: 'K', nazev: 'Klempířská'),
    );

    final posunuta = zakazka.copyWith(status: OrderStatus.values.last);

    expect(posunuta.typZakazky?.kod, 'K');
  });
}
