import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/rest_service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/domain/repositories/service_order_repository.dart';

/// Jedna zakázka v takovém tvaru, v jakém ji má vracet API.
Map<String, dynamic> _zakazka({String id = 'ZK-26-0418'}) => {
  'id': id,
  'licensePlate': '8AB 4721',
  'model': 'BMW X5 xDrive40d',
  'customerName': 'Petr Novák',
  'status': 'in_repair',
  'branch': 'brno',
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

    test('posun stavu pošle PATCH s novým stavem', () async {
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

      await _zdroj(client).updateStatus('ZK-26-0418', 'quality_check');

      expect(metoda, 'PATCH');
      expect(jsonDecode(telo), {'status': 'quality_check'});
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
        () => _zdroj(client).updateStatus('ZK-26-0398', 'picked_up'),
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
}
