import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/core/utils/stari_vozu.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/dilensky_stav.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/moje_prava.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/plan_klempirny.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/plan/domain/kapacita.dart';
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
    MojePrava? prava,
  }) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    zdroj = FakeServiceOrderDataSource(zakazky);
    if (prava != null) zdroj.prava = prava;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(const Nastaveni()),
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

    group('vytížení dílen', () {
      PolozkaPlanu radek(List<UkonPlanu> ukony) => PolozkaPlanu(
        zakazkaId: 'Z',
        spz: '',
        model: '',
        zakaznik: '',
        plan: PlanKlempirny(
          od: ukony.first.od,
          do_: ukony.last.do_,
          ukony: ukony,
        ),
      );
      UkonPlanu u(String od, String do_, int? aw, [Dilna? dilna]) => UkonPlanu(
        id: 1,
        typ: const TypUkonu(kod: 'x', nazev: 'X', barva: '#000000'),
        od: DateTime.parse(od),
        do_: DateTime.parse(do_),
        aw: aw,
        dilna: dilna ?? Dilna.klempirna,
      );

      test('osa má i víkend', () {
        final osa = dnyOsy(DateTime(2026, 11, 2), 1);
        expect(osa, hasLength(7));
        expect(jeVikend(osa[4]), isFalse);
        expect(jeVikend(osa[5]), isTrue);
      });

      test('AW se dělí rovným dílem na pracovní dny, víkend se nepočítá', () {
        // Pátek až pondělí: dva pracovní dny, 96 AW = 8 h.
        final v = vytizeniDilen([
          radek([u('2026-11-06', '2026-11-09', 96)]),
        ]);
        expect(v[DateTime(2026, 11, 6)]?[Dilna.klempirna], 4);
        expect(v[DateTime(2026, 11, 7)], isNull);
        expect(v[DateTime(2026, 11, 9)]?[Dilna.klempirna], 4);
      });

      test('úkon bez AW se nepočítá, dílny se nesčítají', () {
        final v = vytizeniDilen([
          radek([
            u('2026-11-04', '2026-11-04', null),
            u('2026-11-04', '2026-11-04', 24),
            u('2026-11-04', '2026-11-04', 12, Dilna.lakovna),
          ]),
        ]);
        expect(v[DateTime(2026, 11, 4)], {
          Dilna.klempirna: 2,
          Dilna.lakovna: 1,
        });
      });

      test('barva vytížení, výchozí dílna a hodiny', () {
        expect(urovenVytizeni(49), UrovenVytizeni.nizke);
        expect(urovenVytizeni(50), UrovenVytizeni.ok);
        expect(urovenVytizeni(84), UrovenVytizeni.ok);
        expect(urovenVytizeni(85), UrovenVytizeni.plno);
        expect(urovenVytizeni(100), UrovenVytizeni.plno);
        expect(urovenVytizeni(101), UrovenVytizeni.pres);
        expect(Dilna.vychoziProTyp('demontaz'), Dilna.klempirna);
        expect(Dilna.vychoziProTyp('priprava_lak'), Dilna.priprava);
        expect(Dilna.vychoziProTyp('lakovna'), Dilna.lakovna);
        expect(hodinyText(12.5), '12,5');
        expect(hodinyText(12), '12');
      });

      test('stav pruhu: prošlý nehotový je po termínu', () {
        final b = u('2026-11-02', '2026-11-03', 12);
        final p = radek([b]);
        expect(stavPruhu(p, b, DateTime(2026, 11, 2)), StavPruhu.planovano);
        expect(stavPruhu(p, b, DateTime(2026, 11, 5)), StavPruhu.poTerminu);
      });
    });

    group('osa průběhu', () {
      DilenskyStav stav(
        String id,
        String? kod,
        String nazev,
        String zadano, {
        String? dokonceno,
        String? dokoncil,
      }) => DilenskyStav(
        id: id,
        kod: kod,
        nazev: nazev,
        autor: 'Jan',
        zadano: DateTime.parse(zadano),
        dokonceno: dokonceno == null ? null : DateTime.parse(dokonceno),
        dokoncil: dokoncil,
      );
      UkonPlanu u(int id, String kod, String nazev, String od, String do_) =>
          UkonPlanu(
            id: id,
            typ: TypUkonu(kod: kod, nazev: nazev, barva: '#000000'),
            od: DateTime.parse(od),
            do_: DateTime.parse(do_),
          );
      PlanKlempirny planZ(List<UkonPlanu> ukony) =>
          PlanKlempirny(od: ukony.first.od, do_: ukony.last.do_, ukony: ukony);
      final plny = planZ([
        u(1, 'demontaz', 'Demontáž', '2026-11-02', '2026-11-03'),
        u(2, 'klempirna', 'Klempířské práce', '2026-11-04', '2026-11-05'),
        u(3, 'priprava', 'Příprava na lak', '2026-11-05', '2026-11-09'),
        u(4, 'lakovna', 'Lakovna', '2026-11-10', '2026-11-11'),
      ]);
      final historie = [
        stav('s3', 'klempirna', 'Klempířské práce', '2026-11-04T15:17:00'),
        stav('s2', null, 'Čeká na schválení', '2026-11-03T12:00:00'),
        stav('s1', 'demontaz', 'Demontáž', '2026-11-02T08:00:00'),
      ];

      test('nahoře co čeká, pak co probíhá, dole hotové', () {
        expect(
          osaPrubehu(plny, historie).map((p) => (p.nazev, p.stav)).toList(),
          [
            ('Lakovna', StavPolozky.ceka),
            ('Příprava na lak', StavPolozky.dalsi),
            ('Klempířské práce', StavPolozky.probiha),
            ('Čeká na schválení', StavPolozky.hotovo),
            ('Demontáž', StavPolozky.hotovo),
          ],
        );
      });

      test('stav bez úkonu je mimo plán, konec je začátek dalšího stavu', () {
        final mimo = osaPrubehu(
          plny,
          historie,
        ).firstWhere((p) => p.nazev == 'Čeká na schválení');
        expect(mimo.mimoPlan, isTrue);
        expect(mimo.do_, DateTime(2026, 11, 4, 15, 17));
      });

      test('Dokončit uzavře krok, i když další ještě nezačal', () {
        final osa = osaPrubehu(plny, [
          stav(
            's3',
            'klempirna',
            'Klempířské práce',
            '2026-11-04T15:17:00',
            dokonceno: '2026-11-05T10:00:00',
            dokoncil: 'Petr',
          ),
        ]);
        final krok = osa.firstWhere((p) => p.nazev == 'Klempířské práce');
        expect(krok.stav, StavPolozky.hotovo);
        expect(krok.kdo, 'Petr');
        expect(krok.kdy, DateTime(2026, 11, 5, 10));
        expect(osa.any((p) => p.stav == StavPolozky.probiha), isFalse);
      });

      test('stav bez kódu se k úkonu pozná podle názvu', () {
        final osa = osaPrubehu(
          planZ([u(1, 'geometrie', 'Geometrie', '2026-11-02', '2026-11-03')]),
          [stav('s', null, 'Geometrie', '2026-11-02T08:00:00')],
        );
        expect(osa, hasLength(1));
        expect(osa.single.stav, StavPolozky.probiha);
      });

      test('bez plánu nic není mimo plán a probíhající nemá konec', () {
        final osa = osaPrubehu(null, historie);
        expect(osa.every((p) => !p.mimoPlan), isTrue);
        expect(osa.first.stav, StavPolozky.probiha);
        expect(osa.first.do_, isNull);
      });

      test('návrat ke kroku: k úkonu patří poslední záznam', () {
        final osa = osaPrubehu(
          planZ([u(1, 'lakovna', 'Lakovna', '2026-11-02', '2026-11-03')]),
          [
            stav('s3', 'lakovna', 'Lakovna', '2026-11-05T08:00:00'),
            stav('s2', 'montaz', 'Montáž', '2026-11-04T08:00:00'),
            stav('s1', 'lakovna', 'Lakovna', '2026-11-03T08:00:00'),
          ],
        );
        expect(osa.where((p) => p.nazev == 'Lakovna'), hasLength(2));
        expect(osa.firstWhere((p) => p.zaznam?.id == 's1').mimoPlan, isFalse);
        expect(osa.firstWhere((p) => p.ukon != null).zaznam?.id, 's3');
      });
    });

    test('kolik času uplynulo od příjmu', () {
      final dnes = DateTime(2026, 11, 4, 12);
      expect(predKolika(DateTime(2026, 11, 4, 8), dnes), 'dnes');
      expect(predKolika(DateTime(2026, 11, 3, 23), dnes), 'včera');
      expect(predKolika(DateTime(2026, 11, 1), dnes), 'před 3 dny');
      expect(predKolika(DateTime(2026, 9, 20), dnes), 'před měsícem');
      expect(predKolika(DateTime(2026, 6, 1), dnes), 'před 5 měsíci');
      expect(predKolika(DateTime(2025, 10, 1), dnes), 'před rokem');
      expect(predKolika(DateTime(2024, 11, 11), dnes), 'před 2 lety');
      expect(predKolika(DateTime(2026, 11, 5), dnes), '');
    });

    test('kolik zbývá do termínu', () {
      final dnes = DateTime(2026, 11, 4, 12);
      expect(zbyvaDo(DateTime(2026, 11, 4, 18), dnes), 'dnes');
      expect(zbyvaDo(DateTime(2026, 11, 5), dnes), 'zítra');
      expect(zbyvaDo(DateTime(2026, 11, 7), dnes), 'zbývají 3 dny');
      expect(zbyvaDo(DateTime(2026, 11, 9), dnes), 'zbývá 5 dní');
      expect(zbyvaDo(DateTime(2026, 11, 3), dnes), '');
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

    expect(find.byKey(const Key('osa-prubehu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-pridat-ukon')));
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
    expect(lze(), isFalse, reason: 'bez AW se neuloží');
    await tester.enterText(find.byKey(const Key('plan-aw')), '4');
    await tester.pump();
    expect(find.text('48 AW = 4 h práce'), findsOneWidget);
    expect(lze(), isTrue);

    // Přepnutí jednotky zadanou délku převede, nepřečte ji jinak.
    TextField pole() => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('plan-aw')),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    );
    await tester.tap(find.text('AW').last);
    await tester.pumpAndSettle();
    expect(pole().controller!.text, '48');
    expect(find.text('48 AW = 4 h práce'), findsOneWidget);
    await tester.tap(find.text('Hodiny'));
    await tester.pumpAndSettle();
    expect(pole().controller!.text, '4');

    await tester.tap(ulozit);
    await tester.pumpAndSettle();

    final ulozeny = zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!;
    expect(ulozeny['from'], '2026-10-14');
    expect(ulozeny['to'], '2026-10-16');
    expect(ulozeny['paintCode'], 'C4P');
    expect(ulozeny['status'], 'naplanovano');
    expect(find.text('LAKOVNA  14.–16. 10.', findRichText: true), findsNothing);
    expect(find.text('14.–16. 10. 2026'), findsOneWidget);
    // Zaplánování stav nezapíše - úkon čeká na Zahájit.
    expect(find.byKey(const Key('plan-zahajit-1')), findsOneWidget);
    expect(
      zdroj.ulozeneDto('ZK-26-0001').statusCode,
      'klempirna',
      reason: 'dílenský stav zůstal, jaký byl',
    );
  });

  testWidgets('zakázka jiného útvaru kartu klempírny nemá', (tester) async {
    await spust(tester, zakazky: [buildOrderDto(utvar: '11211')]);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-pridat-ukon')), findsNothing);
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
    expect(find.text('12. 10. – 18. 10. 2026'), findsOneWidget);
    expect(find.text('14. 10.'), findsOneWidget);
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
    expect(
      druhy,
      greaterThan(den),
      reason: 'čt-ne proti po-st, víkend je na ose',
    );

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
    expect(find.text('19. 10. – 25. 10. 2026'), findsOneWidget);
    // Blok je minulý týden - zakázka zůstane, jen s textem, kdy plán je.
    expect(find.byKey(const Key('plan-jindy-ZK-26-0001')), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-dnes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14 dní'));
    await tester.pumpAndSettle();
    expect(find.text('12. 10. – 25. 10. 2026'), findsOneWidget);
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
    await tester.enterText(find.byKey(const Key('plan-aw')), '4');
    await tester.pump();
    await tester.tap(find.byKey(const Key('plan-ulozit')));
    await tester.pumpAndSettle();
    expect(zdroj.ulozeneDto('ZK-26-0001').bodyshopPlan!['status'], 'hotovo');
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

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
    await tester.enterText(find.byKey(const Key('plan-aw')), '4');
    await tester.pump();
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

  testWidgets('průběh opravy: teď, probíhá, zahájení a sbalená historie', (
    tester,
  ) async {
    await spust(
      tester,
      velikost: const Size(1280, 1400),
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          // Aktuální stav je Klempířské práce.
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
              ukon(2, '2026-10-13', '2026-10-14', typ: 'klempirna'),
              ukon(3, '2026-10-15', '2026-10-16', typ: 'lakovna'),
            ],
          ),
        ),
      ],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.text('PRŮBĚH OPRAVY'), findsOneWidget);
    expect(find.text('POSTUP ZAKÁZKY'), findsNothing);
    expect(find.text('TEĎ'), findsNothing);
    expect(find.byKey(const Key('osa-probiha')), findsOneWidget);
    expect(find.textContaining('Dokončeno'), findsOneWidget);
    expect(find.text('Další na řadě'), findsOneWidget);
    // Probíhající ani hotový se znovu zahájit nedá, další na řadě ano.
    expect(find.byKey(const Key('plan-zahajit-1')), findsNothing);
    expect(find.byKey(const Key('plan-zahajit-2')), findsNothing);
    final zahajit = find.byKey(const Key('plan-zahajit-3'));
    expect(zahajit, findsOneWidget);
    expect(find.byKey(const Key('dokoncit-stav')), findsOneWidget);

    // Stav je předvybraný podle úkonu, zápis jde stejnou cestou jako jindy.
    await tester.ensureVisible(zahajit);
    await tester.tap(zahajit);
    await tester.pumpAndSettle();
    expect(find.text('Zahájit: LAKOVNA'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Zahájit'));
    await tester.pumpAndSettle();
    expect(zdroj.ulozeneDto('ZK-26-0001').statusCode, 'lakovna');

    // Teď probíhá lakovna, předchozí krok tím skončil.
    expect(find.byKey(const Key('plan-zahajit-3')), findsNothing);
    expect(find.byKey(const Key('plan-zahajit-2')), findsNothing);
    expect(find.textContaining('Dokončeno'), findsNWidgets(2));

    // Dokončit krok uzavře a další se sám nezahájí.
    final dokoncit = find.byKey(const Key('dokoncit-stav'));
    await tester.ensureVisible(dokoncit);
    await tester.pumpAndSettle();
    await tester.tap(dokoncit);
    await tester.pumpAndSettle();
    expect(dokoncit, findsNothing);
    expect(find.byKey(const Key('osa-probiha')), findsNothing);
    expect(zdroj.ulozeneDto('ZK-26-0001').statusCode, 'lakovna');
    expect(find.textContaining('· dokončeno'), findsOneWidget);
  });

  testWidgets('hlavička dne: vytížení z AW a kapacity, víkend zavřeno', (
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
            '2026-10-12',
            ukony: [
              {
                ...ukon(1, '2026-10-12', '2026-10-12'),
                'aw': 24,
                'workshop': 'klempirna',
              },
            ],
          ),
        ),
      ],
    );
    zdroj.kapacityPlanu = {
      '1': {
        DateTime(2026, 10, 12): {
          Dilna.klempirna: const KapacitaDne(aw: 192, lidi: 2),
        },
      },
    };
    await otevriPlanovac(tester);

    // V hlavičce jen ukazatel: názvy dílen až v detailu, písmena pod segmenty.
    expect(find.byKey(const Key('plan-detail-vytizeni')), findsNothing);
    expect(find.text('Klempírna'), findsNothing);
    expect(find.text('K'), findsNWidgets(5));
    expect(
      tester.widget<Text>(find.byKey(const Key('plan-mini-12'))).data,
      '13 %',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('plan-mini-hodiny-12'))).data,
      '2/16 h',
    );
    // Víkend ukazatel nemá.
    expect(find.byKey(const Key('plan-mini-17')), findsNothing);

    await tester.tap(find.byKey(const Key('plan-hlavicka-12')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-vytizeni-klempirna')),
        matching: find.text('2 h · 13 %'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-vytizeni-celkem')),
        matching: find.text('2/16 h · 13 %'),
      ),
      findsOneWidget,
    );
    // Bez kapacity pomlčka.
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-vytizeni-lakovna')),
        matching: find.text('0 h · –'),
      ),
      findsOneWidget,
    );

    // Klepnutí mimo detail jen zavře, úkon se tím nezakládá.
    await tester.tapAt(const Offset(5, 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-detail-vytizeni')), findsNothing);
    expect(find.byKey(const Key('plan-pridat-ukon')), findsNothing);

    expect(find.byKey(const Key('plan-legenda-vytizeni')), findsOneWidget);
    expect(find.byKey(const Key('plan-legenda')), findsOneWidget);
  });

  group('kapacita dílen', () {
    const karosar = ClovekKapacity(
      id: 1,
      jmeno: 'Karosář Jedna',
      tarify: ['Karosář'],
      dilnaPodleTarifu: Dilna.klempirna,
    );
    const lakyrnik = ClovekKapacity(
      id: 2,
      jmeno: 'Lakýrník Dva',
      tarify: ['Lakýrník'],
      dilnaPodleTarifu: Dilna.lakovna,
    );

    Future<void> otevriKapacitu(WidgetTester tester) async {
      await otevriPlanovac(tester);
      await tester.tap(find.byKey(const Key('plan-kapacita')));
      await tester.pumpAndSettle();
    }

    test('počet lidí krát 90 AW, nepřítomnost a ruční den', () {
      final po = DateTime(2026, 11, 9);
      final ut = DateTime(2026, 11, 10);
      final kapacity = kapacityObdobi(
        [
          karosar.copyWith(
            nepritomnosti: [NepritomnostCloveka(id: 1, od: po, do_: po)],
          ),
          lakyrnik,
        ],
        [RucniDenKapacity(den: ut, dilna: Dilna.priprava, aw: 45)],
        po,
        DateTime(2026, 11, 14),
      );
      expect(kapacity[po]![Dilna.klempirna]!.aw, 0);
      expect(kapacity[ut]![Dilna.klempirna]!.aw, 90);
      expect(kapacity[po]![Dilna.lakovna]!.hodin, 7.5);
      // Ruční den má přednost, jinak dílna bez lidí kapacitu nemá.
      expect(kapacity[po]![Dilna.priprava], isNull);
      expect(kapacity[ut]![Dilna.priprava]!.rucne, isTrue);
      // Víkend se nepočítá.
      expect(kapacity[DateTime(2026, 11, 14)], isNull);
    });

    test('kapacita dílny je součet lidí, nepřítomný se nepočítá', () {
      final po = DateTime(2026, 11, 9);
      final ut = DateTime(2026, 11, 10);
      final kapacity = kapacityObdobi(
        [
          karosar,
          karosar.copyWith(awDen: 48),
          karosar.copyWith(
            awDen: 60,
            nepritomnosti: [NepritomnostCloveka(id: 1, od: po, do_: po)],
          ),
        ],
        const [],
        po,
        ut,
      );
      expect(kapacity[po]![Dilna.klempirna]!.aw, 90 + 48);
      expect(kapacity[po]![Dilna.klempirna]!.lidi, 2);
      expect(kapacity[ut]![Dilna.klempirna]!.aw, 90 + 48 + 60);
    });

    test('kapacita člověka ze serveru, bez hodnoty výchozí', () {
      expect(ClovekKapacity.fromJson(const {'id': 1, 'dailyAw': 48}).awDen, 48);
      expect(ClovekKapacity.fromJson(const {'id': 1}).awDen, awClovekDen);
    });

    test('text do pole: uložení beze změny AW nezmění, ať je jakékoli', () {
      expect(hodnotaKapacity(90, JednotkaKapacity.hodiny), '7,5');
      expect(hodnotaKapacity(48, JednotkaKapacity.hodiny), '4');
      expect(hodnotaKapacity(27, JednotkaKapacity.hodiny), '2,25');
      expect(hodnotaKapacity(27, JednotkaKapacity.aw), '27');
      for (var aw = 1; aw <= 9999; aw++) {
        final text = hodnotaKapacity(aw, JednotkaKapacity.hodiny);
        expect(prevedNaAw(text, JednotkaKapacity.hodiny), aw);
      }
    });

    test('zadaná kapacita člověka: prázdné výchozí, nula a přes 24 h ne', () {
      expect(kapacitaClovekaNaAw('4', JednotkaKapacity.hodiny), 48);
      expect(kapacitaClovekaNaAw('48', JednotkaKapacity.aw), 48);
      expect(kapacitaClovekaNaAw('  ', JednotkaKapacity.hodiny), awClovekDen);
      expect(kapacitaClovekaNaAw('24', JednotkaKapacity.hodiny), awClovekMax);
      expect(kapacitaClovekaNaAw('24,5', JednotkaKapacity.hodiny), isNull);
      expect(kapacitaClovekaNaAw('0', JednotkaKapacity.aw), isNull);
    });

    test('přeřazený člověk se počítá jinde, vyřazený nikde', () {
      expect(
        lakyrnik.copyWith(prirazeno: () => 'priprava').dilna,
        Dilna.priprava,
      );
      expect(lakyrnik.copyWith(prirazeno: () => zarazeniMimo).dilna, isNull);
      expect(lakyrnik.dilna, Dilna.lakovna);
    });

    test('zadaná kapacita na AW', () {
      expect(prevedNaAw('7,5', JednotkaKapacity.hodiny), 90);
      expect(prevedNaAw('180', JednotkaKapacity.aw), 180);
      expect(prevedNaAw('', JednotkaKapacity.aw), isNull);
      expect(prevedNaAw('-1', JednotkaKapacity.aw), isNull);
      expect(prevedNaAw('10000', JednotkaKapacity.aw), isNull);
    });

    test('práva: jen s právem u pobočky, admin všude', () {
      final prava = MojePrava.fromJson({
        'role': 'user',
        'folders': const [],
        'planner': [
          {'code': '1', 'access': 'R', 'capacity': true},
          {'code': '2', 'access': 'W', 'capacity': false},
        ],
      });
      expect(prava.smiKapacitu('1'), isTrue);
      expect(prava.smiKapacitu('2'), isFalse);
      expect(MojePrava.vse.smiKapacitu('2'), isTrue);
    });

    test('kapacita v přehledu plánu ze služby', () {
      final prehled = PrehledPlanu.fromJson({
        'capacity': [
          {
            'branch': '1',
            'day': '2026-11-09',
            'workshop': 'lakovna',
            'aw': 90,
            'people': 1,
            'manual': false,
          },
        ],
      });
      final k = prehled.kapacity['1']![DateTime(2026, 11, 9)]![Dilna.lakovna]!;
      expect(k.hodin, 7.5);
      expect(k.lidi, 1);
    });

    test('vytížení dne: celkem je součet hodin ku součtu kapacit', () {
      final v = vytizeniDne(
        {Dilna.klempirna: 12, Dilna.priprava: 3, Dilna.lakovna: 15},
        {
          Dilna.klempirna: const KapacitaDne(aw: 192),
          Dilna.lakovna: const KapacitaDne(aw: 192),
        },
      );
      expect([for (final (_, r) in v.dilny) r.procent], [75, null, 94]);
      expect(
        [for (final (_, r) in v.dilny) r.uroven],
        [UrovenVytizeni.ok, null, UrovenVytizeni.plno],
      );
      // Práce v dílně bez kapacity se do celku počítá: 30 h z 32 h.
      expect(v.celkem.procent, 94);
      expect(v.celkem.hodinyZKapacity, '30/32 h');

      final bez = vytizeniDne(null, null);
      expect(bez.celkem.procentText, '–');
      expect(bez.celkem.hodinyZKapacity, '0 h');
      // Nulová kapacita: bez práce šedá, s prací přes kapacitu.
      expect(stavVytizeni(0, 0).uroven, isNull);
      expect(stavVytizeni(3, 0).uroven, UrovenVytizeni.pres);
      expect(stavVytizeni(3, 0).procent, isNull);
    });

    test('šířky sloupců: v týdnu stejné, ve 14 dnech úzké víkendy', () {
      final tyden = dnyOsy(DateTime(2026, 11, 2), 1);
      final dva = dnyOsy(DateTime(2026, 11, 2), 2);
      expect(sirkySloupcu(tyden, 1400).toSet(), {200.0});
      expect(sirkySloupcu(tyden, 390).toSet(), {120.0});
      final sirky = sirkySloupcu(dva, 1184);
      expect(sirky[0], 100);
      expect(sirky[5], sirkaVikendu);
      expect(sirky[6], sirkaVikendu);
      expect(sirky[12], sirkaVikendu);
      expect(sirky.fold<double>(0, (a, b) => a + b), 1184);
      expect(sirkySloupcu(dva, 400)[0], 80);
    });

    testWidgets('14 dní: bez písmen a hodin, víkend úzký, pruhy sedí', (
      tester,
    ) async {
      await spust(
        tester,
        zakazky: [
          buildOrderDto(
            utvar: '11215',
            canPlanBodyshop: true,
            bodyshopPlan: plan('2026-10-16', '2026-10-19'),
          ),
        ],
        velikost: const Size(1600, 1000),
      );
      await otevriPlanovac(tester);
      await tester.tap(find.text('14 dní'));
      await tester.pumpAndSettle();

      expect(find.text('K'), findsNothing);
      expect(find.byKey(const Key('plan-mini-hodiny-12')), findsNothing);
      expect(find.byKey(const Key('plan-mini-12')), findsOneWidget);
      expect(find.byKey(const Key('plan-mini-17')), findsNothing);
      final vikend = tester.getSize(find.byKey(const Key('plan-hlavicka-17')));
      expect(vikend.width, sirkaVikendu);
      final den = tester.getSize(find.byKey(const Key('plan-hlavicka-12')));
      expect(den.width, greaterThan(sirkaVikendu));
      expect(find.text('17.'), findsOneWidget);

      // Hlavička i řádek jedou po stejných sloupcích, i přes úzký víkend.
      for (final d in [12, 17, 19, 25]) {
        expect(
          tester.getTopLeft(find.byKey(Key('plan-hlavicka-$d'))).dx,
          moreOrLessEquals(
            tester
                .getTopLeft(
                  find
                      .ancestor(
                        of: find.byKey(Key('plan-den-ZK-26-0001-$d')),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .dx,
          ),
        );
      }
      // Pruh pátek až pondělí začíná v pátek a končí v pondělí.
      final pruh = find.byKey(const Key('plan-pruh-ZK-26-0001-1'));
      expect(
        tester.getTopLeft(pruh).dx,
        moreOrLessEquals(
          tester.getTopLeft(find.byKey(const Key('plan-hlavicka-16'))).dx + 4,
        ),
      );
      expect(
        tester.getTopRight(pruh).dx,
        moreOrLessEquals(
          tester.getTopRight(find.byKey(const Key('plan-hlavicka-19'))).dx - 4,
        ),
      );
    });

    testWidgets('na telefonu zůstane detail na obrazovce', (tester) async {
      await spust(
        tester,
        zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
        velikost: const Size(390, 844),
      );
      await otevriPlanovac(tester);
      await tester.tap(
        find.byKey(const Key('plan-hlavicka-13')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      final detail = find.byKey(const Key('plan-detail-vytizeni'));
      expect(detail, findsOneWidget);
      expect(tester.getTopRight(detail).dx, lessThanOrEqualTo(390));
      expect(tester.getTopLeft(detail).dx, greaterThanOrEqualTo(0));
    });

    testWidgets('segment má barvu pásma, nula s prací je červená', (
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
              '2026-10-12',
              ukony: [
                {
                  ...ukon(1, '2026-10-12', '2026-10-12'),
                  'aw': 90,
                  'workshop': 'lakovna',
                },
              ],
            ),
          ),
        ],
      );
      zdroj.kapacityPlanu = {
        '1': {
          DateTime(2026, 10, 12): {
            Dilna.lakovna: const KapacitaDne(aw: 0),
            Dilna.klempirna: const KapacitaDne(aw: 90),
          },
        },
      };
      await otevriPlanovac(tester);
      Color? barva(String kod) =>
          (tester
                      .widget<Container>(
                        find.byKey(Key('plan-segment-12-$kod')),
                      )
                      .decoration!
                  as BoxDecoration)
              .color;
      expect(barva('lakovna'), const Color(0xFFC62828));
      // Kapacita bez práce je zelená, šedá zůstává jen dílna bez kapacity.
      expect(barva('klempirna'), const Color(0xFF2E9E5B));
      expect(barva('priprava'), const Color(0xFFC9D6DE));
    });

    testWidgets('všichni chybí, bez práce: pomlčka místo procent', (
      tester,
    ) async {
      await spust(
        tester,
        zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
      );
      zdroj.kapacityPlanu = {
        '1': {
          DateTime(2026, 10, 12): {Dilna.klempirna: const KapacitaDne(aw: 0)},
        },
      };
      await otevriPlanovac(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('plan-mini-12'))).data,
        '–',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('plan-mini-hodiny-12'))).data,
        '0/0 h',
      );
    });

    testWidgets('bez práva Kapacita tlačítko není', (tester) async {
      await spust(
        tester,
        zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
        prava: const MojePrava(
          role: 'user',
          poradace: {'10026': 'W'},
          planovac: {'1': 'W'},
        ),
      );
      await otevriPlanovac(tester);
      expect(find.byKey(const Key('plan-kapacita')), findsNothing);
    });

    testWidgets('mistr přeřadí člověka a kapacita plánu se přepočítá', (
      tester,
    ) async {
      await spust(
        tester,
        zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
      );
      zdroj.lideKapacity['1'] = [karosar, lakyrnik];
      await otevriKapacitu(tester);

      expect(find.text('Lakýrník Dva'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kapacita-zarazeni-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Příprava').last);
      await tester.pumpAndSettle();

      expect(zdroj.lideKapacity['1']![1].prirazeno, 'priprava');
      final plan = await zdroj.nactiPlan(
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 12),
      );
      final den = plan.kapacity['1']![DateTime(2026, 10, 12)]!;
      expect(den[Dilna.priprava]!.aw, 90);
      expect(den[Dilna.lakovna], isNull);

      // Zpět na tarif = žádná výjimka.
      await tester.tap(find.byKey(const Key('kapacita-zarazeni-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lakovna').last);
      await tester.pumpAndSettle();
      expect(zdroj.lideKapacity['1']![1].prirazeno, isNull);
    });

    testWidgets('mistr zadá kapacitu člověka v hodinách i AW a vrátí výchozí', (
      tester,
    ) async {
      await spust(
        tester,
        zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
      );
      zdroj.lideKapacity['1'] = [karosar];
      await otevriKapacitu(tester);
      expect(find.text('7,5 h · 90 AW'), findsOneWidget);

      final stitek = find.byKey(const Key('kapacita-clovek-1'));
      final pole = find.byKey(const Key('kapacita-clovek-hodnota'));
      final ulozit = find.byKey(const Key('kapacita-clovek-ulozit'));

      await tester.tap(stitek);
      await tester.pumpAndSettle();
      await tester.enterText(pole, '0');
      await tester.pump();
      expect(tester.widget<FilledButton>(ulozit).onPressed, isNull);
      await tester.enterText(pole, '4');
      await tester.pump();
      await tester.tap(ulozit);
      await tester.pumpAndSettle();
      expect(zdroj.lideKapacity['1']![0].awDen, 48);
      expect(find.text('4 h · 48 AW'), findsOneWidget);

      await tester.tap(find.text('AW').first);
      await tester.pumpAndSettle();
      expect(find.text('48 AW · 4 h'), findsOneWidget);
      await tester.tap(stitek);
      await tester.pumpAndSettle();
      await tester.enterText(pole, '60');
      await tester.pump();
      await tester.tap(ulozit);
      await tester.pumpAndSettle();
      expect(zdroj.lideKapacity['1']![0].awDen, 60);

      await tester.tap(stitek);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kapacita-clovek-vychozi')));
      await tester.pumpAndSettle();
      expect(zdroj.lideKapacity['1']![0].awDen, awClovekDen);
    });

    testWidgets('mistr zadá a smaže nepřítomnost', (tester) async {
      await spust(
        tester,
        zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
      );
      zdroj.lideKapacity['1'] = [karosar];
      await otevriKapacitu(tester);

      await tester.tap(find.byKey(const Key('kapacita-pridat-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Použít'));
      await tester.pumpAndSettle();

      final nepritomnosti = zdroj.lideKapacity['1']![0].nepritomnosti;
      expect(nepritomnosti, hasLength(1));
      final stitek = find.byKey(
        Key('kapacita-nepritomnost-${nepritomnosti[0].id}'),
      );
      expect(stitek, findsOneWidget);

      await tester.tap(find.byTooltip('Smazat nepřítomnost'));
      await tester.pumpAndSettle();
      expect(zdroj.lideKapacity['1']![0].nepritomnosti, isEmpty);
      expect(stitek, findsNothing);
    });

    testWidgets('ruční den v hodinách i návrat podle lidí', (tester) async {
      await spust(
        tester,
        zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
      );
      await otevriKapacitu(tester);

      final ulozit = find.byKey(const Key('kapacita-ulozit-den'));
      expect(tester.widget<FilledButton>(ulozit).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('kapacita-hodnota')), '7,5');
      await tester.pump();
      await tester.tap(ulozit);
      await tester.pumpAndSettle();

      final dny = zdroj.rucniDnyKapacity['1']!;
      expect(dny.single.aw, 90);
      expect(dny.single.dilna, Dilna.klempirna);

      await tester.tap(find.text('Podle lidí'));
      await tester.pumpAndSettle();
      expect(zdroj.rucniDnyKapacity['1'], isEmpty);
    });
  });

  testWidgets('úkon bez AW v plánu upozorní', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-12', '2026-10-13'),
        ),
      ],
    );
    await otevriPlanovac(tester);

    expect(find.text('doplnit AW'), findsOneWidget);
  });

  testWidgets('bez plánu: jen stavy a řádek, že plán není', (tester) async {
    await spust(
      tester,
      velikost: const Size(1280, 1400),
      zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.text('jen stavy'), findsOneWidget);
    expect(find.text('Zakázka nemá plán'), findsOneWidget);
    expect(find.byKey(const Key('plan-pridat-ukon')), findsOneWidget);
  });

  testWidgets('hlavička: stavy, zařazení, přidání stavu a Převzít zakázku', (
    tester,
  ) async {
    await spust(tester, zakazky: [buildOrderDto(utvar: '11211')]);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.text('Dílna: Klempířské práce'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('hlavicka-zarazeni')),
        matching: find.textContaining('11211', findRichText: true),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();
    expect(find.text('Přidat stav'), findsWidgets);
    await tester.tap(find.text('Zrušit').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prevzit-hlavicka')), findsOneWidget);
  });

  // Rozhoduje šířka detailu, ne okna - vedle seznamu je detail užší.
  for (final sirka in const [1600.0, 1180.0, 820.0, 390.0]) {
    testWidgets('hlavička na šířce $sirka: údaje v mřížce, nic nepřeteče', (
      tester,
    ) async {
      await spust(
        tester,
        velikost: Size(sirka, 900),
        zakazky: [buildOrderDto(utvar: '11211')],
      );
      await tester.tap(find.text('1AA 1111'));
      await tester.pumpAndSettle();
      final pruh = find.byKey(const Key('hlavicka-udaje'));
      expect(pruh, findsOneWidget);
      final detail = tester.getSize(pruh).width;
      final sloupcu = detail >= 1250
          ? 7
          : detail >= 560
          ? 4
          : 2;
      expect(
        find.descendant(of: pruh, matching: find.byType(IntrinsicHeight)),
        findsNWidgets((7 / sloupcu).ceil()),
      );
      // VIN se vždy vejde celé.
      final vin = find.text('WBATEST0000000001');
      expect(vin, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hlavička: kdo zakázku zpracovává, Převzít už nevidí', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11211',
          assignee: {
            'id': 501,
            'name': 'Dvořák Jan',
            // Velikost písmen nehraje roli.
            'email': 'Jan.Dvorak@renocar.cz',
          },
        ),
      ],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pridat-stav')), findsOneWidget);
    expect(find.byKey(const Key('prevzit-hlavicka')), findsNothing);
  });

  testWidgets('zakázka mimo klempírnu má dál jen postup stavů', (tester) async {
    await spust(tester, zakazky: [buildOrderDto(utvar: '11211')]);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.text('POSTUP ZAKÁZKY'), findsOneWidget);
    expect(find.text('PRŮBĚH OPRAVY'), findsNothing);
    expect(find.byKey(const Key('plan-pridat-ukon')), findsNothing);
    expect(find.text('Zakázka nemá plán'), findsNothing);
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
    expect(lze(), isFalse, reason: 'bez AW se neuloží');
    await tester.enterText(find.byKey(const Key('plan-aw')), '1');
    await tester.pump();
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

    expect(find.text('12.–13. 10.'), findsOneWidget);
    expect(find.textContaining('Dokončeno'), findsOneWidget);
    expect(find.byKey(const Key('plan-zahajit-2')), findsOneWidget);
    expect(find.text('14.–16. 10.'), findsOneWidget);

    // Nový úkon navazuje na konec plánu - z pátku na pondělí.
    await tester.tap(find.byKey(const Key('plan-pridat-ukon')));
    await tester.pumpAndSettle();
    expect(find.text('19. 10. – 19. 10. 2026'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('plan-aw')), '4');
    await tester.pump();
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
    await tester.enterText(find.byKey(const Key('plan-aw')), '4');
    await tester.pump();
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
    expect(find.byKey(const Key('osa-prubehu')), findsOneWidget);
    expect(find.byKey(const Key('plan-zahajit-1')), findsOneWidget);
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

  group('Zahájit a Dokončit ve formuláři úkonu', () {
    final prubeh = find.byKey(const Key('plan-okno-prubeh'));
    final zahajit = find.byKey(const Key('plan-okno-zahajit'));
    final dokoncit = find.byKey(const Key('plan-okno-dokoncit'));
    Finder pruh(int id) => find.byKey(Key('plan-pruh-ZK-26-0001-$id'));
    Finder stav(String text) =>
        find.descendant(of: prubeh, matching: find.text(text));
    ServiceOrderDto zakazka() => buildOrderDto(
      utvar: '11215',
      canPlanBodyshop: true,
      // Aktuální stav je Klempířské práce.
      bodyshopPlan: plan(
        '2026-10-12',
        '2026-10-16',
        ukony: [
          ukon(1, '2026-10-12', '2026-10-13', typ: 'klempirna'),
          ukon(2, '2026-10-14', '2026-10-14', typ: 'montaz'),
          ukon(3, '2026-10-15', '2026-10-16', typ: 'lakovna'),
        ],
      ),
    );

    testWidgets('zahájí a dokončí konkrétní úkon, řádek tlačítka nemá', (
      tester,
    ) async {
      await spust(tester, zakazky: [zakazka()]);
      await otevriPlanovac(tester);
      expect(zahajit, findsNothing);
      expect(dokoncit, findsNothing);

      // I úkon, který není na řadě, jde zahájit: stavy se přeskakují.
      await tester.tap(pruh(3));
      await tester.pumpAndSettle();
      expect(stav('Čeká'), findsOneWidget);
      expect(dokoncit, findsNothing);
      await tester.tap(zahajit);
      await tester.pumpAndSettle();
      expect(find.text('Zahájit: LAKOVNA'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Zahájit'));
      await tester.pumpAndSettle();
      expect(zdroj.ulozeneDto('ZK-26-0001').statusCode, 'lakovna');

      await tester.tap(pruh(3));
      await tester.pumpAndSettle();
      expect(stav('Probíhá'), findsOneWidget);
      expect(zahajit, findsNothing);
      await tester.tap(dokoncit);
      await tester.pumpAndSettle();
      expect(prubeh, findsNothing, reason: 'okno se zavřelo');
      expect(zdroj.ulozeneDto('ZK-26-0001').statusCode, 'lakovna');

      await tester.tap(pruh(3));
      await tester.pumpAndSettle();
      expect(stav('Dokončeno'), findsOneWidget);
      expect(zahajit, findsNothing);
      expect(dokoncit, findsNothing);
    });

    testWidgets('nový úkon průběh nemá', (tester) async {
      await spust(tester, zakazky: [zakazka()]);
      await otevriPlanovac(tester);
      await tester.tap(find.byKey(const Key('plan-den-ZK-26-0001-12')));
      await tester.pumpAndSettle();
      expect(find.text('Přidat úkon'), findsOneWidget);
      expect(prubeh, findsNothing);
    });
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
    expect(find.byKey(const Key('uzivatel-novy-email')), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byKey(const Key('prubeh-doplnek')),
        matching: find.text('KÓD 475', findRichText: true),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('otevrit-planovac')));
    await tester.pumpAndSettle();
    expect(find.text('Plán klempírny a lakovny'), findsOneWidget);
  });
}
