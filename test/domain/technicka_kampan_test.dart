import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/akce/domain/technicka_kampan.dart';
import 'package:renoworkshop/src/features/akce/presentation/kampane_panel.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';

void main() {
  group('VINy vložené z Excelu', () {
    test('po řádcích, čárkou i středníkem; malá písmena a pomlčky nevadí', () {
      final r = rozpoznejViny(
        'WBA3A5C51DF123456\r\n'
        'wba3a5c51df654321, F123456;\tG-765432\n\n',
      );
      expect(r.platne, [
        'WBA3A5C51DF123456',
        'WBA3A5C51DF654321',
        'F123456',
        'G765432',
      ]);
      expect(r.neplatne, isEmpty);
    });

    test('duplicity jednou, neplatné zvlášť', () {
      final r = rozpoznejViny('F123456\nF123456\nVIN\nWBA3A5C51DO123456');
      expect(r.platne, ['F123456']);
      // „VIN" z hlavičky sloupce a O místo nuly.
      expect(r.neplatne, ['VIN', 'WBA3A5C51DO123456']);
    });

    test('prázdný text nic nenajde', () {
      final r = rozpoznejViny('  \n ');
      expect(r.platne, isEmpty);
      expect(r.neplatne, isEmpty);
    });
  });

  test('počty slovy', () {
    expect(pocetKampani(1), '1 technická kampaň');
    expect(pocetKampani(3), '3 technické kampaně');
    expect(pocetKampani(5), '5 technických kampaní');
    expect(pocetVinu(1), '1 VIN');
    expect(pocetVinu(4), '4 VINy');
    expect(pocetVinu(12), '12 VINů');
  });

  test('zakázka nese kampaně ke svému VINu, starší API žádné', () {
    final zaklad = {
      'id': 'Z1',
      'licensePlate': '1AA 1111',
      'model': 'BMW 320d',
      'customerName': 'Petr Novák',
      'vin': 'WBA3A5C51DF123456',
      'mechanicName': null,
    };
    final s = ServiceOrderDto.fromJson({
      ...zaklad,
      'technicalCampaigns': [
        {'id': 'k1', 'code': ' ', 'title': 'Airbag', 'text': 'Dotáhnout.'},
      ],
    }).toDomain();
    expect(s.technickeKampane.single.nazev, 'Airbag');
    expect(s.technickeKampane.single.kod, isNull);

    expect(ServiceOrderDto.fromJson(zaklad).toDomain().technickeKampane, []);
  });

  test('kampaň ze serveru', () {
    final p = PrehledKampani.fromJson({
      'canEdit': true,
      'campaigns': [
        {
          'id': 'k1',
          'code': '0032760300',
          'title': 'Airbag',
          'text': '',
          'vehicleCount': 34,
        },
      ],
    });
    expect(p.muzeUpravovat, isTrue);
    expect(p.kampane.single.pocetVozidel, 34);
    expect(p.kampane.single.toJson(['F123456']), {
      'code': '0032760300',
      'title': 'Airbag',
      'text': '',
      'vins': ['F123456'],
    });
  });
}
