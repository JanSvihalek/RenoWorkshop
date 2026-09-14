import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/service_order.dart';

ServiceOrder zakazka({String? pojistovna, String? cislo}) => ServiceOrder(
  id: 'ZK-1',
  licensePlate: '1AA 1111',
  model: 'BMW',
  customerName: 'Novák',
  vin: 'W',
  pojistovna: pojistovna,
  cisloPojistneUdalosti: cislo,
);

void main() {
  test('pojišťovna a číslo události na jeden řádek', () {
    expect(
      zakazka(pojistovna: 'Kooperativa', cislo: '42012').pojisteniPopisek,
      'Kooperativa · PU 42012',
    );
  });

  test('jen jedno z nich', () {
    expect(zakazka(pojistovna: 'Allianz').pojisteniPopisek, 'Allianz');
    // Číslo bez pojišťovny se ukáže taky - v Heliosu ji někdo nevyplnil,
    // ale událost to je.
    expect(zakazka(cislo: '42012').pojisteniPopisek, 'PU 42012');
  });

  test('bez pojištění nic', () {
    expect(zakazka().pojisteniPopisek, isNull);
  });
}
