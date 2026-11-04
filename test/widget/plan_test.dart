import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/plan_klempirny.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/plan/domain/prehled_planu.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Plán klempírny a lakovny: zaplánování z detailu zakázky a plánovač
/// (přepínač aplikací) s časovou osou po pracovních dnech, průběhem na
/// dílně a filtry jako u seznamu zakázek.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  // Středa - týden je 12.-16. 10. 2026.
  final dnes = DateTime(2026, 10, 14);
  late FakeServiceOrderDataSource zdroj;

  Map<String, dynamic> ukon(
    int id,
    String od,
    String do_, {
    String typ = 'lakovna',
    String stav = 'naplanovano',
  }) => {
    'id': id,
    'type': {'code': typ, 'label': typ.toUpperCase(), 'color': '#BE123C'},
    'from': od,
    'to': do_,
    'note': '',
    'status': stav,
    'plannedBy': 'Jan Dvořák',
  };

  Map<String, dynamic> plan(
    String od,
    String do_, {
    String? kod,
    String stav = 'naplanovano',
    List<Map<String, dynamic>>? ukony,
  }) => {
    'from': od,
    'to': do_,
    'paintCode': kod,
    'note': '',
    'status': stav,
    'plannedBy': 'Jan Dvořák',
    'blocks': ukony ?? [ukon(1, od, do_, stav: stav)],
  };

  Future<void> spust(
    WidgetTester tester, {
    required List<ServiceOrderDto> zakazky,
    Size velikost = const Size(1280, 1000),
  }) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    zdroj = FakeServiceOrderDataSource(zakazky);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(const Nastaveni(skenovatPoOtevreni: false)),
          ),
          authRepositoryProvider.overrideWithValue(
            PlaceholderAuthRepository(
              ssoDelay: Duration.zero,
              biometricDelay: Duration.zero,
            ),
          ),
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          dnesProvider.overrideWithValue(dnes),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  /// Plánovač se otevírá přepínačem aplikací - na tabletu položka
  /// Aplikace v navigaci, na telefonu mřížka v hlavičce zakázek.
  Future<void> otevriPlanovac(WidgetTester tester) async {
    final nav = find.byKey(const Key('nav-aplikace'));
    await tester.tap(
      nav.evaluate().isNotEmpty
          ? nav
          : find.byKey(const Key('prepinac-aplikaci')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aplikace-plan')));
    await tester.pumpAndSettle();
  }

  group('doména plánu', () {
    test('pondělí a pracovní dny', () {
      expect(pondeli(dnes), DateTime(2026, 10, 12));
      expect(pondeli(DateTime(2026, 10, 18)), DateTime(2026, 10, 12));
      final dny = pracovniDny(DateTime(2026, 10, 12), 2);
      expect(dny, hasLength(10));
      expect(dny[4], DateTime(2026, 10, 16));
      expect(dny[5], DateTime(2026, 10, 19));
    });

    test('společné kódy laku - aspoň dvě zakázky, bez ohledu na velikost', () {
      PolozkaPlanu p(String id, String? kod, {String od = '2026-10-12'}) =>
          PolozkaPlanu.fromJson({
            'orderId': id,
            'licensePlate': id,
            'plan': plan(od, od, kod: kod),
          });
      final kody = spolecneKody(
        [
          p('A', '416'),
          p('B', 'c4p'),
          p('C', '416'),
          p('D', 'C4P '),
          p('E', '416'),
          p('F', 'A96'),
          p('G', null),
          // Mimo období se nepočítá.
          p('H', 'A96', od: '2026-11-02'),
          PolozkaPlanu.fromJson({'orderId': 'I', 'plan': null}),
        ],
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 16),
      );
      expect(kody.map((k) => (k.kod, k.polozky.length)), [
        ('416', 3),
        ('C4P', 2),
      ]);
    });

    test('kód laku: ručně z plánu, jinak barva vozu z Heliosu', () {
      PolozkaPlanu p(String id, String? kod, Object? barva) =>
          PolozkaPlanu.fromJson({
            'orderId': id,
            'licensePlate': id,
            'plan': plan('2026-10-12', '2026-10-12', kod: kod),
            'vehicleColor': barva,
          });
      const barva = {'code': '475', 'name': 'Black Sapphire'};
      expect(p('A', ' c4p ', barva).kodLaku, 'C4P');
      expect(p('B', null, barva).kodLaku, '475');
      expect(p('C', null, {'code': ' ', 'name': 'Bílá'}).kodLaku, isNull);
      expect(p('D', null, null).barva, isNull);
      expect(p('E', null, barva).barva!.popis, '475 · Black Sapphire');

      final kody = spolecneKody(
        [p('F', null, barva), p('G', null, barva), p('H', '300', barva)],
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 16),
      );
      expect(kody.map((k) => (k.kod, k.polozky.length)), [('475', 2)]);
    });

    test('společné kódy jen ze zakázek s lakovnou v období', () {
      PolozkaPlanu p(String id, String typ) => PolozkaPlanu.fromJson({
        'orderId': id,
        'licensePlate': id,
        'plan': plan(
          '2026-10-12',
          '2026-10-12',
          kod: '416',
          ukony: [ukon(1, '2026-10-12', '2026-10-12', typ: typ)],
        ),
      });
      final kody = spolecneKody(
        [p('A', 'lakovna'), p('B', 'puvodni'), p('C', 'demontaz')],
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 16),
      );
      expect(kody.single.polozky.map((p) => p.zakazkaId), ['A', 'B']);

      expect(
        spolecneKody(
          [p('C', 'demontaz'), p('D', 'montaz')],
          DateTime(2026, 10, 12),
          DateTime(2026, 10, 16),
        ),
        isEmpty,
      );
    });

    test('úkony bez překryvu v jedné lince, při překryvu pod sebou', () {
      final dny = pracovniDny(DateTime(2026, 10, 12), 1);
      UkonPlanu u(int id, String od, String do_) =>
          UkonPlanu.fromJson(ukon(id, od, do_));
      Map<int, int> linky(List<UkonPlanu> ukony) => {
        for (final p in pruhyVOse(ukony, dny).pruhy) p.ukon.id: p.linka,
      };

      expect(pruhyVOse(const [], dny).linek, 0);
      // Navazují - jedna linka.
      expect(
        linky([
          u(1, '2026-10-12', '2026-10-13'),
          u(2, '2026-10-14', '2026-10-15'),
        ]),
        {1: 0, 2: 0},
      );
      // Stejný den - pod sebou, třetí se vrátí do uvolněné linky.
      final prekryv = [
        u(3, '2026-10-15', '2026-10-16'),
        u(1, '2026-10-12', '2026-10-14'),
        u(2, '2026-10-14', '2026-10-14'),
      ];
      expect(linky(prekryv), {1: 0, 2: 1, 3: 0});
      expect(pruhyVOse(prekryv, dny).linek, 2);
      // Jen přes víkend - na ose není.
      expect(pruhyVOse([u(4, '2026-10-17', '2026-10-18')], dny).pruhy, isEmpty);
    });

    test('nový úkon: další typ v pořadí a pracovní den po konci plánu', () {
      const typy = [
        TypUkonu(kod: 'demontaz', nazev: 'Demontáž', barva: ''),
        TypUkonu(kod: 'lakovna', nazev: 'Lakovna', barva: ''),
      ];
      PlanKlempirny s(String typ, String do_) => PlanKlempirny.fromJson(
        plan('2026-10-12', do_, ukony: [ukon(1, '2026-10-12', do_, typ: typ)]),
      );
      expect(vychoziTypUkonu(typy, null)?.kod, 'demontaz');
      expect(vychoziTypUkonu(const [], null), isNull);
      expect(
        vychoziTypUkonu(typy, s('demontaz', '2026-10-13'))?.kod,
        'lakovna',
      );
      // Poslední v číselníku, nebo vyřazený - zase od začátku.
      expect(
        vychoziTypUkonu(typy, s('lakovna', '2026-10-13'))?.kod,
        'demontaz',
      );
      expect(
        vychoziTypUkonu(typy, s('puvodni', '2026-10-13'))?.kod,
        'demontaz',
      );

      expect(navazujiciDen(s('lakovna', '2026-10-13')), DateTime(2026, 10, 14));
      // Z pátku přes víkend na pondělí.
      expect(navazujiciDen(s('lakovna', '2026-10-16')), DateTime(2026, 10, 19));
    });

    test('souhrn plánu přes úkony a mezera mezi nimi', () {
      final p = PlanKlempirny.zUkonu([
        UkonPlanu.fromJson(ukon(2, '2026-10-26', '2026-10-27', stav: 'hotovo')),
        UkonPlanu.fromJson(ukon(1, '2026-10-05', '2026-10-06', stav: 'hotovo')),
      ]);
      expect(p.od, DateTime(2026, 10, 5));
      expect(p.do_, DateTime(2026, 10, 27));
      expect(p.hotovo, isTrue);
      expect(p.ukony.map((u) => u.id), [1, 2]);
      // V týdnu mezi úkony zakázka v plánu nic nemá.
      expect(
        p.prekryva(DateTime(2026, 10, 12), DateTime(2026, 10, 16)),
        isFalse,
      );
      expect(p.prekryva(DateTime(2026, 10, 5), DateTime(2026, 10, 9)), isTrue);
    });

    test('řádky: v období od začátku, jindy, bez plánu od nejstarší', () {
      PolozkaPlanu p(String id, {String? od, String? prijato}) =>
          PolozkaPlanu.fromJson({
            'orderId': id,
            'receivedAt': prijato,
            'plan': od == null ? null : plan(od, od),
          });
      final r = rozdelPolozky(
        [
          p('bez-novy', prijato: '2026-10-10T08:00:00'),
          p('pozdeji', od: '2026-10-15'),
          p('jindy', od: '2026-11-02'),
          p('drive', od: '2026-10-12'),
          p('bez-stary', prijato: '2026-09-01T08:00:00'),
        ],
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 16),
      );
      expect(r.vObdobi.map((p) => p.zakazkaId), ['drive', 'pozdeji']);
      expect(r.jindy.map((p) => p.zakazkaId), ['jindy']);
      expect(r.bezPlanu.map((p) => p.zakazkaId), ['bez-stary', 'bez-novy']);
    });
  });

  testWidgets('klempířskou zakázku jde z detailu zaplánovat', (tester) async {
    await spust(
      tester,
      zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-karta')), findsOneWidget);
    await tester.tap(find.byKey(const Key('zaplanovat-klempirnu')));
    await tester.pumpAndSettle();

    final ulozit = find.byKey(const Key('plan-ulozit'));
    bool lze() => tester.widget<FilledButton>(ulozit).onPressed != null;
    expect(lze(), isFalse, reason: 'bez dnů se neuloží');

    await tester.tap(find.byKey(const Key('plan-obdobi')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14').first);
    await tester.pump();
    await tester.tap(find.text('16').first);
    await tester.pump();
    await tester.tap(find.text('Použít'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan-kod-laku')), 'c4p');
    await tester.pump();
    expect(lze(), isTrue);

    await tester.tap(ulozit);
    await tester.pumpAndSettle();

    final ulozeny = zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!;
    expect(ulozeny['from'], '2026-10-14');
    expect(ulozeny['to'], '2026-10-16');
    expect(ulozeny['paintCode'], 'C4P');
    expect(ulozeny['status'], 'naplanovano');
    expect(find.text('14. 10. – 16. 10. 2026 · 3 dny'), findsOneWidget);
    expect(find.text('NAPLÁNOVÁNO'), findsOneWidget);
  });

  testWidgets('zakázka jiného útvaru kartu klempírny nemá', (tester) async {
    await spust(tester, zakazky: [buildOrderDto(utvar: '11211')]);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-karta')), findsNothing);
  });

  testWidgets('záložka Plán ukáže týden pobočky a společné kódy', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-12', '2026-10-14', kod: '416'),
        ),
        buildOrderDto(
          id: 'ZK-26-0002',
          licensePlate: '2BB 2222',
          utvar: '11215',
          canPlanBodyshop: true,
          // Přes víkend do dalšího týdne - pruh je useknutý v pátek.
          bodyshopPlan: plan('2026-10-15', '2026-10-20', kod: '416'),
        ),
        buildOrderDto(
          id: 'ZK-26-0003',
          licensePlate: '3CC 3333',
          utvar: '12215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-13', '2026-10-13', kod: 'C4P'),
        ),
      ],
    );
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();

    expect(zdroj.obdobiPlanu, (DateTime(2026, 10, 12), DateTime(2026, 10, 18)));
    expect(find.text('12. 10. – 16. 10. 2026'), findsOneWidget);
    expect(find.text('St 14. 10.'), findsOneWidget);
    // Brno: dvě zakázky, obě s kódem 416.
    expect(find.byKey(const Key('plan-radek-ZK-26-0001')), findsOneWidget);
    expect(find.byKey(const Key('plan-radek-ZK-26-0002')), findsOneWidget);
    expect(find.byKey(const Key('plan-radek-ZK-26-0003')), findsNothing);
    expect(find.byKey(const Key('plan-kod-416')), findsOneWidget);

    // Pruh první zakázky zabírá po-st, tedy tři dny.
    final den = tester
        .getSize(find.byKey(const Key('plan-pruh-ZK-26-0001-1')))
        .width;
    final druhy = tester
        .getSize(find.byKey(const Key('plan-pruh-ZK-26-0002-1')))
        .width;
    expect(den, greaterThan(druhy), reason: 'po-st proti čt-pá');

    await tester.tap(find.byKey(const Key('plan-pobocka-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-radek-ZK-26-0003')), findsOneWidget);
    expect(find.byKey(const Key('plan-radek-ZK-26-0001')), findsNothing);
    expect(find.byKey(const Key('plan-spolecne-kody')), findsNothing);
  });

  testWidgets('posun na další týden a 14 dní', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-12', '2026-10-14'),
        ),
      ],
    );
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plan-dal')));
    await tester.pumpAndSettle();
    expect(find.text('19. 10. – 23. 10. 2026'), findsOneWidget);
    // Blok je minulý týden - zakázka zůstane, jen s textem, kdy plán je.
    expect(find.byKey(const Key('plan-jindy-ZK-26-0001')), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-dnes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14 dní'));
    await tester.pumpAndSettle();
    expect(find.text('12. 10. – 23. 10. 2026'), findsOneWidget);
    expect(zdroj.obdobiPlanu, (DateTime(2026, 10, 12), DateTime(2026, 10, 25)));
    expect(find.byKey(const Key('plan-radek-ZK-26-0001')), findsOneWidget);
  });

  testWidgets('pruh v plánu otevře úpravu - hotovo zezelená, zrušení zmizí', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-12', '2026-10-14', kod: '416'),
        ),
      ],
    );
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plan-pruh-ZK-26-0001-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-hotovo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('plan-ulozit')));
    await tester.pumpAndSettle();
    expect(zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!['status'], 'hotovo');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-pruh-ZK-26-0001-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-zrusit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-zrusit-potvrdit')));
    await tester.pumpAndSettle();
    expect(zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan, isNull);
    // Zakázka v plánu zůstane - jen bez bloku.
    expect(find.text('BEZ PLÁNU · 1'), findsOneWidget);
  });

  testWidgets('u jednoho vozu jde naplánovat víc úkonů s různými typy', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-12', '2026-10-13', kod: '416'),
        ),
      ],
    );
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();
    final radek = find.byKey(const Key('plan-radek-ZK-26-0001'));
    final vyskaPred = tester.getSize(radek).height;

    // Klepnutí na den pod pruhem přidá úkon, nepřepíše první.
    await tester.tap(find.byKey(const Key('plan-den-ZK-26-0001-13')));
    await tester.pumpAndSettle();
    expect(find.text('Přidat úkon'), findsOneWidget);
    expect(find.text('13. 10. – 13. 10. 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-typ')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montáž').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-ulozit')));
    await tester.pumpAndSettle();

    final ulozeny = zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!;
    expect(ulozeny['blocks'], hasLength(2));
    expect(ulozeny['paintCode'], '416');
    expect((ulozeny['blocks'] as List).last['type']['code'], 'montaz');
    expect(find.byKey(const Key('plan-pruh-ZK-26-0001-1')), findsOneWidget);
    expect(find.byKey(const Key('plan-pruh-ZK-26-0001-2')), findsOneWidget);

    // Oba 13. 10. - jedou pod sebou.
    final prvni = tester.getTopLeft(
      find.byKey(const Key('plan-pruh-ZK-26-0001-1')),
    );
    final druhy = tester.getTopLeft(
      find.byKey(const Key('plan-pruh-ZK-26-0001-2')),
    );
    expect(druhy.dy, prvni.dy + 34);
    expect(tester.getSize(radek).height, greaterThanOrEqualTo(vyskaPred));

    // Úprava změní jen ten úkon, smazání druhého nechá první.
    await tester.tap(find.byKey(const Key('plan-pruh-ZK-26-0001-2')));
    await tester.pumpAndSettle();
    expect(find.text('Upravit úkon'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-zrusit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ostatní úkony'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-zrusit-potvrdit')));
    await tester.pumpAndSettle();
    expect(
      zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!['blocks'],
      hasLength(1),
    );
    expect(find.byKey(const Key('plan-pruh-ZK-26-0001-2')), findsNothing);
    expect(find.byKey(const Key('plan-pruh-ZK-26-0001-1')), findsOneWidget);
  });

  testWidgets('pomalé načtení typů: výchozí typ se ukáže, až přijdou', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
    );
    zdroj.cekaniNaTypy = Completer<void>();
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-den-ZK-26-0001-14')));
    await tester.pumpAndSettle();

    bool lze() =>
        tester
            .widget<FilledButton>(find.byKey(const Key('plan-ulozit')))
            .onPressed !=
        null;
    expect(find.byKey(const Key('plan-typ-nacita')), findsOneWidget);
    expect(lze(), isFalse, reason: 'bez typu se neuloží');

    zdroj.cekaniNaTypy!.complete();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-typ')),
        matching: find.text('Demontáž'),
      ),
      findsOneWidget,
    );
    expect(lze(), isTrue);
  });

  testWidgets('typy se nenačetly: okno to řekne a jde to zkusit znovu', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
    );
    zdroj.typySelzou = true;
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-den-ZK-26-0001-14')));
    await tester.pumpAndSettle();
    expect(find.text('Typy úkonů se nepodařilo načíst.'), findsOneWidget);

    zdroj.typySelzou = false;
    await tester.tap(find.byKey(const Key('plan-typy-znovu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-typ')), findsOneWidget);
  });

  testWidgets('v kartě zakázky je seznam úkonů a jde přidat další', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan(
            '2026-10-12',
            '2026-10-16',
            ukony: [
              ukon(
                1,
                '2026-10-12',
                '2026-10-13',
                typ: 'demontaz',
                stav: 'hotovo',
              ),
              ukon(2, '2026-10-14', '2026-10-16'),
            ],
          ),
        ),
      ],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.text('DEMONTAZ'), findsOneWidget);
    expect(find.text('LAKOVNA'), findsOneWidget);
    expect(find.text('HOTOVO'), findsOneWidget);
    expect(find.text('NAPLÁNOVÁNO'), findsOneWidget);
    expect(find.text('14. 10. – 16. 10. 2026 · 3 dny'), findsOneWidget);

    // Nový úkon navazuje na konec plánu - z pátku na pondělí.
    await tester.tap(find.byKey(const Key('plan-pridat-ukon')));
    await tester.pumpAndSettle();
    expect(find.text('19. 10. – 19. 10. 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-ulozit')));
    await tester.pumpAndSettle();
    expect(
      zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!['blocks'],
      hasLength(3),
    );

    // Klepnutí na úkon ho otevře k úpravě.
    await tester.tap(find.byKey(const Key('plan-ukon-1')));
    await tester.pumpAndSettle();
    expect(find.text('Upravit úkon'), findsOneWidget);
  });

  testWidgets('v plánu jsou i zakázky bez plánu - klepnutí na den zaplánuje', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(utvar: '11215', canPlanBodyshop: true),
        buildOrderDto(
          id: 'ZK-26-0002',
          licensePlate: '2BB 2222',
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-11-02', '2026-11-04'),
        ),
        // Servis, ne klempírna - v plánu není.
        buildOrderDto(id: 'ZK-26-0003', utvar: '11211'),
      ],
    );
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();

    expect(find.text('BEZ PLÁNU · 1'), findsOneWidget);
    expect(find.text('NAPLÁNOVANÉ JINDY · 1'), findsOneWidget);
    expect(find.byKey(const Key('plan-jindy-ZK-26-0002')), findsOneWidget);
    expect(find.byKey(const Key('plan-radek-ZK-26-0003')), findsNothing);

    // Klepnutí na středu - nový plán má středu předvyplněnou.
    await tester.tap(find.byKey(const Key('plan-den-ZK-26-0001-14')));
    await tester.pumpAndSettle();
    expect(find.text('14. 10. – 14. 10. 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-ulozit')));
    await tester.pumpAndSettle();

    expect(zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!['from'], '2026-10-14');
    expect(find.byKey(const Key('plan-pruh-ZK-26-0001-1')), findsOneWidget);
    expect(find.text('BEZ PLÁNU · 1'), findsNothing);
  });

  testWidgets('klepnutí na zakázku v plánu otevře její detail', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-12', '2026-10-14', kod: '416'),
        ),
      ],
    );
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-zakazka-ZK-26-0001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-karta')), findsOneWidget);
    expect(find.text('NAPLÁNOVÁNO'), findsOneWidget);
  });

  testWidgets('na telefonu se osa posouvá do stran', (tester) async {
    await spust(
      tester,
      velikost: const Size(400, 860),
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-12', '2026-10-14', kod: '416'),
        ),
      ],
    );
    await otevriPlanovac(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-osa-posun')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plánovač: průběh na dílně u zakázky, klepnutím nový stav', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          status: 'Lakovna',
          statusCode: 'lakovna',
          vehicleColor: {'code': '475', 'name': 'Black Sapphire'},
        ),
      ],
    );
    await otevriPlanovac(tester);
    // U vozu kód barvy z Heliosu.
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-barva-ZK-26-0001')),
        matching: find.text('KÓD 475', findRichText: true),
      ),
      findsOneWidget,
    );
    final stav = find.byKey(const Key('plan-stav-ZK-26-0001'));
    expect(stav, findsOneWidget);
    // Pod zákazníkem VIN a kdo zodpovídá.
    expect(
      tester.widget<Text>(find.byKey(const Key('plan-vuz-ZK-26-0001'))).data,
      allOf(contains('VIN '), contains('Zodpovídá: Jan Dvořák')),
    );
    expect(
      find.descendant(of: stav, matching: find.text('Lakovna')),
      findsOneWidget,
    );

    await tester.tap(stav);
    await tester.pumpAndSettle();
    expect(find.text('Přidat stav'), findsWidgets);
  });

  testWidgets('plánovač: filtry jako u seznamu a stav plánu', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-13', '2026-10-14', kod: '416'),
        ),
        buildOrderDto(
          id: 'ZK-26-0002',
          licensePlate: '2BB 2222',
          utvar: '11215',
          canPlanBodyshop: true,
        ),
      ],
    );
    await otevriPlanovac(tester);
    expect(find.byKey(const Key('plan-radek-ZK-26-0002')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('plan-hledani')), '1AA');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-radek-ZK-26-0002')), findsNothing);
    expect(find.text('1 z 2 zakázek'), findsOneWidget);

    // Je na konci vodorovně posouvané řady filtrů.
    await tester.ensureVisible(find.byKey(const Key('plan-zrusit-filtry')));
    await tester.tap(find.byKey(const Key('plan-zrusit-filtry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-radek-ZK-26-0002')), findsOneWidget);
  });

  testWidgets('plánovač: admin má v hlavičce Admin', (tester) async {
    await spust(tester, zakazky: [buildOrderDto()]);
    await otevriPlanovac(tester);
    await tester.tap(find.byKey(const Key('plan-admin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uzivatel-pridat')), findsOneWidget);
  });

  testWidgets('plánovač: z hlavičky se jde do nastavení', (tester) async {
    await spust(tester, zakazky: [buildOrderDto()]);
    await otevriPlanovac(tester);
    await tester.tap(find.byKey(const Key('plan-nastaveni')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Plán klempírny a lakovny'), findsNothing);
  });

  testWidgets('plánovač: šipka zpět vrátí do zakázek', (tester) async {
    await spust(tester, zakazky: [buildOrderDto()]);
    await otevriPlanovac(tester);
    expect(find.text('Plán klempírny a lakovny'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-zpet-do-zakazek')));
    await tester.pumpAndSettle();
    expect(find.text('Plán klempírny a lakovny'), findsNothing);
    expect(find.text('Zakázky na dílně'), findsOneWidget);
  });

  testWidgets('telefon: mřížka v hlavičce, plánovač bez prohlížeče', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [buildOrderDto()],
      velikost: const Size(400, 860),
    );
    expect(find.byKey(const Key('nav-aplikace')), findsNothing);
    await tester.tap(find.byKey(const Key('prepinac-aplikaci')));
    await tester.pumpAndSettle();
    expect(find.text('APLIKACE RENOWORKSHOP'), findsOneWidget);
    expect(find.text('Jste zde'), findsOneWidget);
    await tester.tap(find.byKey(const Key('aplikace-plan')));
    await tester.pumpAndSettle();
    expect(find.text('Plán klempírny a lakovny'), findsOneWidget);
  });

  testWidgets('naplánovaná zakázka: termín v seznamu, karta s plánovačem', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-14', '2026-10-16'),
          vehicleColor: {'code': '475', 'name': 'Black Sapphire'},
        ),
      ],
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('karta-plan')),
        matching: find.text('Klempírna 14. 10. – 16. 10. 2026'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    final karta = find.byKey(const Key('plan-karta'));
    expect(
      find.descendant(
        of: karta,
        matching: find.text('KÓD 475', findRichText: true),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('otevrit-planovac')));
    await tester.pumpAndSettle();
    expect(find.text('Plán klempírny a lakovny'), findsOneWidget);
  });
}
