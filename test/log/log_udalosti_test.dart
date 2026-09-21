import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:renoworkshop/src/core/log/log_udalosti.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/rest_service_order_data_source.dart';

/// Služba bez sítě: pamatuje si dávky, umí selhat.
class _FalesnaSluzba implements OdesilaniUdalosti {
  final List<List<Map<String, Object?>>> davky = [];
  bool selze = false;

  @override
  Future<void> odesliUdalosti(
    List<Map<String, Object?>> udalosti, {
    required String zarizeni,
    String? verze,
  }) async {
    if (selze) throw Exception('bez sítě');
    davky.add(udalosti);
  }
}

void main() {
  late _FalesnaSluzba sluzba;
  late PametoveUlozisteLogu uloziste;
  late bool prihlasen;

  LogUdalosti novyLog() => LogUdalosti(
    odesilani: () => sluzba,
    prihlasen: () => prihlasen,
    uloziste: uloziste,
    verze: () => '1.2.0 (80)',
    zarizeni: 'android 14',
    ted: () => DateTime(2026, 9, 21, 10, 5),
  );

  setUp(() {
    sluzba = _FalesnaSluzba();
    uloziste = PametoveUlozisteLogu();
    prihlasen = true;
  });

  test('obrazovka se zapíše jednou i s číslem zakázky', () {
    final log = novyLog()
      ..obrazovka('/orders')
      ..obrazovka('/orders')
      ..obrazovka('/orders/ZK-26-0418/fotky')
      ..udalost('foceni', detail: 'vin');

    expect(log.fronta.map((u) => u.nazev), [
      'obrazovka',
      'obrazovka',
      'foceni',
    ]);
    // Krok na obrazovce zakázky se k ní přiřadí sám.
    expect(log.fronta.last.zakazka, 'ZK-26-0418');
    expect(log.fronta.last.toJson(), {
      'at': '2026-09-21T10:05:00',
      'type': 'event',
      'name': 'foceni',
      'screen': '/orders/ZK-26-0418/fotky',
      'order': 'ZK-26-0418',
      'detail': 'vin',
    });
  });

  test('bez přihlášení se nic neposílá, po něm ano', () async {
    prihlasen = false;
    final log = novyLog()..udalost('prihlaseni_chyba');

    await log.odesli();
    expect(sluzba.davky, isEmpty);
    expect(log.fronta, hasLength(1));

    prihlasen = true;
    await log.odesli();
    expect(sluzba.davky.single.single['name'], 'prihlaseni_chyba');
    expect(log.fronta, isEmpty);
  });

  test('když odeslání selže, fronta počká na příště', () async {
    sluzba.selze = true;
    final log = novyLog()..udalost('foceni');

    await log.odesli();
    expect(log.fronta, hasLength(1));

    sluzba.selze = false;
    await log.odesli();
    expect(log.fronta, isEmpty);
    expect(sluzba.davky, hasLength(1));
  });

  test('chyba přežije pád aplikace - uloží se hned a obnoví', () {
    prihlasen = false;
    novyLog().chyba(
      'chyba_aplikace',
      StateError('Bad state'),
      zasobnik: StackTrace.current,
    );

    // Nový start aplikace se stejným úložištěm.
    final poPadu = novyLog()..obnovZUloziste();
    final chyba = poPadu.fronta.single;
    expect(chyba.jeChyba, isTrue);
    expect(chyba.nazev, 'chyba_aplikace');
    expect(chyba.text, startsWith('Bad state: Bad state'));
  });

  test('plná fronta zahazuje nejdřív události, ne chyby', () {
    prihlasen = false;
    final log = novyLog()..chyba('chyba_aplikace', 'první');
    for (var i = 0; i < LogUdalosti.maxFronta + 10; i++) {
      log.udalost('obrazovka_$i');
    }

    expect(log.fronta, hasLength(LogUdalosti.maxFronta));
    expect(log.fronta.first.nazev, 'chyba_aplikace');
  });

  test('číslo zakázky z cesty obrazovky', () {
    expect(zakazkaZCesty('/orders/ZK-26-0418'), 'ZK-26-0418');
    expect(zakazkaZCesty('/prijem/ZK%2F26%2F1'), 'ZK/26/1');
    expect(zakazkaZCesty('/vyhledavani'), isNull);
  });

  group('odesílání přes službu', () {
    RestServiceOrderDataSource zdroj(MockClient client, List<String> hlasene) =>
        RestServiceOrderDataSource(
          baseUrl: Uri.parse(
            'https://rendcapp.renocar.local/renoworkshop/api/',
          ),
          tokenProvider: () async => 'token',
          client: client,
          onChyba: (nazev, detail) => hlasene.add('$nazev $detail'),
        );

    test('dávka jde na POST /events se zařízením a verzí', () async {
      late http.Request odeslany;
      final client = MockClient((request) async {
        odeslany = request;
        return http.Response('', 204);
      });

      await zdroj(client, []).odesliUdalosti(
        [
          {'at': '2026-09-21T10:05:00', 'type': 'event', 'name': 'foceni'},
        ],
        zarizeni: 'android 14',
        verze: '1.2.0 (80)',
      );

      expect(odeslany.method, 'POST');
      expect(odeslany.url.path, '/renoworkshop/api/events');
      expect(odeslany.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(odeslany.body), {
        'device': 'android 14',
        'appVersion': '1.2.0 (80)',
        'events': [
          {'at': '2026-09-21T10:05:00', 'type': 'event', 'name': 'foceni'},
        ],
      });
    });

    test('výpadek sítě se hlásí do logu, u samotného logu ne', () async {
      final hlasene = <String>[];
      final client = MockClient(
        (request) async => throw http.ClientException('bez sítě'),
      );
      final sluzba = zdroj(client, hlasene);

      await expectLater(sluzba.fetchOrders(), throwsA(anything));
      await expectLater(
        sluzba.odesliUdalosti(const [], zarizeni: 'x'),
        throwsA(anything),
      );

      // Jen seznam zakázek - pokus o odeslání logu by jinak bez sítě
      // přidával další a další záznamy.
      expect(hlasene, ['sit_nedostupna orders: GET bez sítě']);
    });
  });
}
