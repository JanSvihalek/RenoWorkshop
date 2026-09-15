import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/rest_service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/domain/repositories/service_order_repository.dart';
import 'package:renoworkshop/src/features/fotodokumentace/domain/entities/fotka.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/prijem.dart';

/// Jedna zakázka v takovém tvaru, v jakém ji má vracet API.
Map<String, dynamic> _zakazka({String id = 'ZK-26-0418'}) => {
  'id': id,
  'licensePlate': '8AB 4721',
  'model': 'BMW X5 xDrive40d',
  'customerName': 'Petr Novák',
  'status': 'in_repair',
  'branch': {'code': '1', 'label': 'Brno'},
  'department': {'code': '11211', 'label': 'Servis BMW Brno'},
  'receivedAt': '2026-08-21T07:15:00',
  'dueAt': '2026-08-26T16:00:00',
  'vin': 'WBAKS4105L9KL83914',
  'mechanicName': 'Jan Dvořák',
  'serviceAdvisorName': 'Martina Horáková',
  'bay': 'Stání 4',
  'notes': <dynamic>[],
  'workItems': <dynamic>[],
};

RestServiceOrderDataSource _zdroj(
  MockClient client, {
  Future<String?> Function()? token,
}) {
  return RestServiceOrderDataSource(
    baseUrl: Uri.parse('https://rendcapp.renocar.local/renoworkshop/api/'),
    tokenProvider: token ?? () async => 'testovaci-token',
    client: client,
  );
}

void main() {
  group('RestServiceOrderDataSource', () {
    test('seznam zakázek volá GET /orders s tokenem', () async {
      late http.BaseRequest zachyceno;
      final client = MockClient((request) async {
        zachyceno = request;
        return http.Response(
          jsonEncode([_zakazka()]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final zakazky = await _zdroj(client).fetchOrders();

      expect(zakazky, hasLength(1));
      expect(zakazky.single.id, 'ZK-26-0418');
      expect(zachyceno.method, 'GET');
      expect(
        zachyceno.url.toString(),
        'https://rendcapp.renocar.local/renoworkshop/api/orders',
      );
      expect(zachyceno.headers['Authorization'], 'Bearer testovaci-token');
    });

    test('přidání stavu pošle POST na /stavy', () async {
      late String telo;
      late String metoda;
      final client = MockClient((request) async {
        metoda = request.method;
        telo = request.body;
        return http.Response(
          jsonEncode(_zakazka()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await _zdroj(client).pridejStav('ZK-26-0418', kod: 'lakovna');

      expect(metoda, 'POST');
      expect(jsonDecode(telo), {'code': 'lakovna'});
    });

    test('předmět opravy pošle PUT a přečte se zpátky', () async {
      late http.Request zachyceno;
      final client = MockClient((request) async {
        zachyceno = request;
        return http.Response(
          jsonEncode({..._zakazka(), 'repairSubject': 'Zadní nárazník'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final dto = await _zdroj(
        client,
      ).ulozPredmetOpravy('ZK-26-0418', 'Zadní nárazník');

      expect(zachyceno.method, 'PUT');
      expect(zachyceno.url.path, endsWith('/orders/ZK-26-0418/repair-subject'));
      expect(jsonDecode(zachyceno.body), {'text': 'Zadní nárazník'});
      expect(dto!.toDomain().predmetOpravy, 'Zadní nárazník');
    });

    test('zakázka ze starší verze API bez předmětu opravy se načte', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(_zakazka()),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final dto = await _zdroj(client).fetchOrder('ZK-26-0418');
      expect(dto!.toDomain().predmetOpravy, isNull);
    });

    test('závady z Heliosu se načtou i s víceřádkovým popisem', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            ..._zakazka(),
            'defects': [
              {
                'id': '9001',
                'code': '001',
                'title': 'Nárazník',
                'text': 'Zadní nárazník\nlakovat',
              },
              {'id': '9002', 'code': '', 'text': 'Geometrie'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final zakazka = (await _zdroj(
        client,
      ).fetchOrder('ZK-26-0418'))!.toDomain();

      expect(zakazka.zavady, hasLength(2));
      expect(zakazka.zavady.first.text, 'Zadní nárazník\nlakovat');
      expect(zakazka.zavady.first.kod, '001');
      expect(zakazka.zavady.first.nazev, 'Nárazník');
      // Starší API bez stručného popisu - závada zůstane jen s poznámkou.
      expect(zakazka.zavady.last.nazev, isNull);
      // Prázdné číslo závady je nevyplněné, ať se neukáže „Závada ".
      expect(zakazka.zavady.last.kod, isNull);
    });

    test('číslo pojistné události se načte, prázdné jako nevyplněné', () async {
      Future<String?> cislo(Object? hodnota) async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({..._zakazka(), 'insuranceClaimNumber': hodnota}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
        final dto = await _zdroj(client).fetchOrder('ZK-26-0418');
        return dto!.toDomain().cisloPojistneUdalosti;
      }

      expect(await cislo('4201234567'), '4201234567');
      expect(await cislo('  '), isNull);
      expect(await cislo(null), isNull);
    });

    test('pojišťovna se načte, bez názvu aspoň s číslem', () async {
      Future<String?> nazev(Object? insurer) async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({..._zakazka(), 'insurer': insurer}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
        final dto = await _zdroj(client).fetchOrder('ZK-26-0418');
        return dto!.toDomain().pojistovna;
      }

      expect(await nazev({'id': 60001, 'name': 'Kooperativa'}), 'Kooperativa');
      // Organizace se ještě nedotáhla - pojistná událost to pořád je.
      expect(await nazev({'id': 60001, 'name': ''}), 'Pojišťovna č. 60001');
      expect(await nazev(null), isNull);
    });

    test('pořadač se načte s krátkým názvem, bez něj s číslem', () async {
      Future<String?> nazev(Object? folder) async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({..._zakazka(), 'folder': folder}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
        final dto = await _zdroj(client).fetchOrder('ZK-26-0418');
        return dto!.toDomain().poradac?.nazev;
      }

      expect(await nazev({'code': '10026', 'label': 'BMW BSL'}), 'BMW BSL');
      expect(await nazev({'code': '10026', 'label': ''}), '10026');
      expect(await nazev(null), isNull);
    });

    test('fotka se nahraje jako JPEG tělo do kategorie', () async {
      late http.Request zachyceno;
      final client = MockClient((request) async {
        zachyceno = request;
        return http.Response(
          jsonEncode({
            'id': 'f1',
            'category': 'poskozeni',
            'size': 3,
            'uploadedBy': 'Jan Dvořák',
            'uploadedAt': '2026-09-15T10:30:00',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final fotka = await _zdroj(client).nahrajFotku(
        'ZK-26-0418',
        KategorieFotky.poskozeni,
        Uint8List.fromList([0xff, 0xd8, 0xff]),
      );

      expect(zachyceno.method, 'POST');
      expect(zachyceno.url.path, endsWith('/orders/ZK-26-0418/photos'));
      expect(zachyceno.url.queryParameters['category'], 'poskozeni');
      // Bez zvolené pobočky rozhoduje server podle pořadače.
      expect(zachyceno.url.queryParameters.containsKey('branch'), isFalse);
      expect(zachyceno.headers['Content-Type'], 'image/jpeg');
      expect(zachyceno.bodyBytes, [0xff, 0xd8, 0xff]);
      expect(fotka.kategorie, KategorieFotky.poskozeni);
    });

    test('zvolená pobočka jde s fotkou jako parametr', () async {
      late http.Request zachyceno;
      final client = MockClient((request) async {
        zachyceno = request;
        return http.Response(
          jsonEncode({
            'id': 'f1',
            'category': 'vin',
            'uploadedAt': '2026-09-15T10:30:00',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await _zdroj(client).nahrajFotku(
        'ZK-26-0418',
        KategorieFotky.vin,
        Uint8List.fromList([0xff, 0xd8, 0xff]),
        pobocka: 'Bubeneč',
      );

      expect(zachyceno.url.queryParameters['branch'], 'Bubeneč');
      expect(zachyceno.url.queryParameters['category'], 'vin');
    });

    group('příjem vozidla', () {
      Map<String, Object?> odpovedPrijmu({String status = 'in_progress'}) => {
        'status': status,
        'startedBy': 'Jan Dvořák',
        'startedAt': '2026-09-15T08:00:00',
        'completedBy': null,
        'completedAt': null,
        'missing': 1,
        'items': [
          {
            'code': 'brzdy',
            'label': 'Brzdy',
            'type': 'check',
            'required': true,
            'checked': true,
            'value': null,
            'note': 'opotřebené destičky',
          },
          {
            'code': 'stk',
            'label': 'Datum platnosti STK',
            'type': 'date',
            'required': true,
            'checked': false,
            'value': null,
            'note': null,
          },
        ],
      };

      http.Response json(Object telo, [int kod = 200]) => http.Response(
        jsonEncode(telo),
        kod,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

      test('načte checklist zakázky', () async {
        late http.Request zachyceno;
        final client = MockClient((request) async {
          zachyceno = request;
          return json(odpovedPrijmu());
        });

        final prijem = await _zdroj(client).prijemZakazky('Z121/26');

        expect(zachyceno.method, 'GET');
        expect(zachyceno.url.path, endsWith('/orders/Z121%2F26/intake'));
        expect(prijem.stav, StavPrijmu.rozpracovany);
        expect(prijem.polozky.first.poznamka, 'opotřebené destičky');
        expect(prijem.chybi, 1);
      });

      test('změna položky pošle jen to, co se mění', () async {
        late http.Request zachyceno;
        final client = MockClient((request) async {
          zachyceno = request;
          return json(odpovedPrijmu());
        });

        await _zdroj(
          client,
        ).zmenPolozku('ZK-26-0418', 'brzdy', ZmenaPolozky.splneno(true));

        expect(zachyceno.method, 'PUT');
        expect(
          zachyceno.url.path,
          endsWith('/orders/ZK-26-0418/intake/items/brzdy'),
        );
        expect(jsonDecode(zachyceno.body), {'checked': true});
      });

      test('nedokončitelný příjem vrátí zprávu ze serveru', () async {
        final client = MockClient(
          (request) async => json({
            'error': {
              'code': 'intake_incomplete',
              'message': 'Příjem nejde dokončit, chybí: Datum platnosti STK.',
            },
          }, 422),
        );

        expect(
          () => _zdroj(client).dokonciPrijem('ZK-26-0418'),
          throwsA(
            isA<ServiceOrderException>().having(
              (e) => e.message,
              'zpráva',
              'Příjem nejde dokončit, chybí: Datum platnosti STK.',
            ),
          ),
        );
      });

      test('znovuotevření je DELETE na dokončení', () async {
        late http.Request zachyceno;
        final client = MockClient((request) async {
          zachyceno = request;
          return json(odpovedPrijmu());
        });

        await _zdroj(client).znovuOtevriPrijem('ZK-26-0418');
        expect(zachyceno.method, 'DELETE');
        expect(
          zachyceno.url.path,
          endsWith('/orders/ZK-26-0418/intake/complete'),
        );
      });
    });

    test('seznam poboček ze serveru', () async {
      late http.Request zachyceno;
      final client = MockClient((request) async {
        zachyceno = request;
        return http.Response(
          jsonEncode(['Brno', 'KCP']),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(await _zdroj(client).slozkyPobocek(), ['Brno', 'KCP']);
      expect(zachyceno.url.path, endsWith('/photos/branches'));
    });

    test('stažená fotka jsou bajty, ne JSON', () async {
      final client = MockClient(
        (request) async => http.Response.bytes(
          [0xff, 0xd8, 0xff, 0xe0],
          200,
          headers: {'content-type': 'image/jpeg'},
        ),
      );

      final bajty = await _zdroj(client).stahniFotku('f1');
      expect(bajty, [0xff, 0xd8, 0xff, 0xe0]);
    });

    test('nenastavené úložiště se ohlásí zprávou ze serveru', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'photo_storage_unavailable',
              'message': 'Úložiště fotodokumentace není na serveru nastavené.',
            },
          }),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      expect(
        () => _zdroj(client).nahrajFotku(
          'ZK-26-0418',
          KategorieFotky.vin,
          Uint8List.fromList([0xff, 0xd8, 0xff]),
        ),
        throwsA(
          isA<ServiceOrderException>().having(
            (e) => e.message,
            'zpráva',
            'Úložiště fotodokumentace není na serveru nastavené.',
          ),
        ),
      );
    });

    test('neznámá zakázka vrací null, ne výjimku', () async {
      final client = MockClient((request) async => http.Response('', 404));

      expect(await _zdroj(client).fetchOrder('ZK-99-9999'), isNull);
    });

    test('vypršené přihlášení se hlásí srozumitelnou hláškou', () async {
      final client = MockClient((request) async => http.Response('', 401));

      expect(
        () => _zdroj(client).fetchOrders(),
        throwsA(
          isA<ServiceOrderException>().having(
            (chyba) => chyba.message,
            'zpráva',
            contains('Přihlášení vypršelo'),
          ),
        ),
      );
    });

    test('chybová zpráva ze serveru se propíše uživateli', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {'message': 'Zakázka je uzavřená.'},
          }),
          409,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(
        () => _zdroj(client).pridejStav('ZK-26-0398', kod: 'vyzvednuto'),
        throwsA(
          isA<ServiceOrderException>().having(
            (chyba) => chyba.message,
            'zpráva',
            'Zakázka je uzavřená.',
          ),
        ),
      );
    });

    test('bez tokenu se hlavička Authorization neposílá', () async {
      late http.BaseRequest zachyceno;
      final client = MockClient((request) async {
        zachyceno = request;
        return http.Response('[]', 200);
      });

      await _zdroj(client, token: () async => null).fetchOrders();

      expect(zachyceno.headers.containsKey('Authorization'), isFalse);
    });

    test('diakritika v odpovědi se dekóduje jako UTF-8', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode([_zakazka()])),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final zakazky = await _zdroj(client).fetchOrders();

      expect(zakazky.single.mechanicName, 'Jan Dvořák');
      expect(zakazky.single.customerName, 'Petr Novák');
    });
  });

  /// Helios nemá datum přijetí ani termín u každé zakázky a API je pak
  /// posílá jako null. Dřív se přetypovávaly na String a celý seznam
  /// spadl na "type Null is not a subtype of type String" - v telefonu
  /// se to projevilo tak, že se nenačetlo vůbec nic.
  test('zakázka bez data přijetí a bez termínu se načte', () async {
    final client = MockClient((request) async {
      final zakazka = _zakazka()
        ..['receivedAt'] = null
        ..['dueAt'] = null;
      return http.Response(
        jsonEncode([zakazka]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final zakazky = await _zdroj(client).fetchOrders();

    expect(zakazky, hasLength(1));
    final zakazka = zakazky.single.toDomain();
    expect(zakazka.receivedAt, isNull);
    expect(zakazka.dueAt, isNull);
    // Bez termínu není co hlídat - zakázka nesmí svítit jako opožděná.
    expect(zakazka.isOverdue(), isFalse);
  });
}
