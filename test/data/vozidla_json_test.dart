import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/vozidla/data/vozidla_data_source.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Tvar odpovědi podle GET /vehicles/{id} v docs/API.md.
Map<String, dynamic> odpovedKarty({
  Map<String, dynamic>? owner,
  Map<String, dynamic>? contact,
}) => {
  'id': 51234,
  'licensePlate': '2BK 9485',
  'vin': 'WBA8E9C50GK123456',
  'model': 'BMW 320d Touring',
  'series': 'F31',
  'fuel': 'Nafta',
  'engine': '',
  'mileage': 123456,
  'soldAt': '2019-05-14',
  'owner': owner,
  'contact': contact,
  'orders': [buildOrderDto(id: 'ZK-23-0777').toJson()],
};

void main() {
  test('karta vozidla z odpovědi API', () {
    final karta = VozidlaJson.karta(
      odpovedKarty(
        owner: {
          'id': 60001,
          'name': 'Stavby Novák s.r.o.',
          'customerNumber': 'Z-10042',
          'ico': '12345678',
          'dic': 'CZ12345678',
          'street': 'Masarykova 123/4',
          'city': 'Brno',
          'zip': '60200',
          'phone': '+420 777 123 456',
          'email': null,
        },
        contact: {'id': 7, 'name': 'Petr Řidič', 'phone': '+420 603 000 111'},
      ),
    );

    expect(karta.id, 51234);
    expect(karta.spz, '2BK 9485');
    expect(karta.tachometr, 123456);
    expect(karta.prodano, DateTime(2019, 5, 14));
    // Prázdný text z Heliosu se bere jako nevyplněno, ať karta řádek vynechá.
    expect(karta.motor, isNull);
    expect(karta.majitel!.adresa, 'Masarykova 123/4, 60200 Brno');
    expect(karta.majitel!.email, isNull);
    expect(karta.kontakt!.jmeno, 'Petr Řidič');
    expect(karta.zakazky.single.id, 'ZK-23-0777');
  });

  test('vůz bez majitele a kontaktu', () {
    final karta = VozidlaJson.karta(odpovedKarty());
    expect(karta.majitel, isNull);
    expect(karta.kontakt, isNull);
  });

  test('adresa jen s obcí nebo úplně bez', () {
    final jenObec = VozidlaJson.karta(
      odpovedKarty(owner: {'name': 'Jan Novák', 'city': 'Lelekovice'}),
    );
    expect(jenObec.majitel!.adresa, 'Lelekovice');

    final bezAdresy = VozidlaJson.karta(odpovedKarty(owner: {'name': 'X'}));
    expect(bezAdresy.majitel!.adresa, isNull);
  });

  test('řádek výsledku hledání', () {
    final vozidlo = VozidlaJson.nalezene({
      'id': 51234,
      'licensePlate': '2BK 9485',
      'vin': 'WBA8E9C50GK123456',
      'model': 'BMW 320d',
      'ownerName': null,
      'orderCount': 3,
    });
    expect(vozidlo.majitel, isNull);
    expect(vozidlo.pocetZakazek, 3);
  });
}
