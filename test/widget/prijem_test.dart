import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/controllers/vozidla_providers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/screens/fotodokumentace_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';
import 'package:renoworkshop/src/features/prijem/data/prijem_data_source.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/dezen.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/prijem.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/vozidlo_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_zakazky_screen.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/widgets/identifikace_karta.dart';

import '../helpers/fake_service_order_data_source.dart';
import '../helpers/zalozky.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> spust(WidgetTester tester) async {
    zdroj = FakeServiceOrderDataSource([
      buildOrderDto(id: 'ZK-26-0001', licensePlate: '2BK 9485'),
      buildOrderDto(id: 'ZK-26-0002', licensePlate: '8AB 4721'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Skener se tu otevírá klepnutím na lupu, ne sám po přepnutí
          // záložky - to zkouší skener_po_otevreni_test.dart.
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
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  Future<void> otevriPrijem(WidgetTester tester) async {
    await tester.tap(find.text('Vozidlo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(VozidloScreen),
        matching: find.byType(TextField),
      ),
      '2bk 94',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    // Krok 1: karta s nalezenou zakázkou - potvrdit, že je to ten vůz.
    await tester.tap(find.byKey(const Key('zahajit-prijem-ZK-26-0001')));
    await tester.pumpAndSettle();
  }

  Finder kontrola(String kod) => find.byKey(Key('kontrola-$kod'));

  Future<void> klepni(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String krok(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('prijem-krok'))).data!;

  String postup(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('prijem-postup'))).data!;

  Future<void> pokracuj(WidgetTester tester, {int kolikrat = 1}) async {
    for (var i = 0; i < kolikrat; i++) {
      await tester.tap(find.byKey(const Key('prijem-pokracovat')));
      await tester.pumpAndSettle();
    }
  }

  ButtonStyleButton dokoncit(WidgetTester tester) => tester
      .widget<ButtonStyleButton>(find.byKey(const Key('dokoncit-prijem')));

  void vyplnVse(String orderId) {
    for (final polozka in vychoziChecklist) {
      zdroj.prijmy.zmen(orderId, polozka.kod, switch (polozka.typ) {
        TypKontroly.datum => ZmenaPolozky.datum(DateTime(2027, 5, 31)),
        TypKontroly.pneu => ZmenaPolozky.dezen(
          const Dezen(lp: 6, pp: 6, lz: 5, pz: 5),
        ),
        TypKontroly.kontrola => ZmenaPolozky.splneno(true),
      });
    }
  }

  testWidgets('příjem jde po krocích: fotky, kontrola, souhrn', (tester) async {
    await spust(tester);
    await otevriPrijem(tester);

    // Krok 1 (identifikace) byl karta na obrazovce hledání.
    expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
    expect(krok(tester), 'Krok 2 ze 4 · Fotodokumentace');
    expect(find.byType(FotodokumentaceObsah), findsOneWidget);
    // Na prvním kroku průvodce není kam se vracet.
    expect(find.byKey(const Key('prijem-zpet')), findsNothing);

    await pokracuj(tester);
    expect(krok(tester), 'Krok 3 ze 4 · Kontrola');
    expect(postup(tester), '0 / 10');

    // Souhrn ukáže, co chybí, a dokončit nejde.
    await pokracuj(tester);
    expect(krok(tester), 'Krok 4 ze 4 · Souhrn');
    expect(find.text('Chybí zkontrolovat: 10'), findsOneWidget);
    expect(dokoncit(tester).onPressed, isNull);

    // Zpět na kontrolu a vyplnit.
    await tester.tap(find.byKey(const Key('prijem-zpet')));
    await tester.pumpAndSettle();
    expect(krok(tester), 'Krok 3 ze 4 · Kontrola');
    for (final polozka in vychoziChecklist) {
      if (polozka.typ == TypKontroly.kontrola) {
        await klepni(tester, kontrola(polozka.kod));
      }
    }
    expect(postup(tester), '8 / 10');
    // Zaškrtnutí se ukládá hned, bez tlačítka Uložit.
    expect(zdroj.prijmy.nacti('ZK-26-0001').pocetVyplnenych, 8);

    // Dezén se měří v okně - u každého kola mm, zimní pod 4 mm červeně.
    await klepni(tester, kontrola('dezen'));
    await tester.tap(find.text('Zimní'));
    await tester.pumpAndSettle();
    for (final (kolo, mm) in [
      ('lp', '6,2'),
      ('pp', '6'),
      ('lz', '3.5'),
      ('pz', '5'),
    ]) {
      await tester.enterText(find.byKey(Key('dezen-$kolo')), mm);
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('dezen-ulozit')));
    await tester.pumpAndSettle();
    expect(
      zdroj.prijmy
          .nacti('ZK-26-0001')
          .polozky
          .firstWhere((p) => p.kod == 'dezen')
          .hodnota,
      'Z;6.2;6;3.5;5',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('dezen-souhrn-dezen'))).data,
      'Zimní · LP 6,2 · PP 6,0 · LZ 3,5 · PZ 5,0 mm · Nutná výměna',
    );
    expect(postup(tester), '9 / 10');

    // STK se nezaškrtává, zadává se datum.
    await klepni(tester, kontrola('stk'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(postup(tester), '10 / 10');

    await pokracuj(tester);
    expect(find.text('Zkontrolováno vše (10)'), findsOneWidget);
    expect(find.byKey(const Key('prijem-souhrn-dezen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dokoncit-prijem')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Příjem dokončen'), findsOneWidget);
    expect(zdroj.prijmy.nacti('ZK-26-0001').stav, StavPrijmu.dokoncen);
    expect(find.byKey(const Key('prijem-hotovo')), findsOneWidget);

    // Dokončený příjem je zamčený.
    await tester.tap(find.byKey(const Key('prijem-zpet')));
    await tester.pumpAndSettle();
    final zmen = zdroj.pocetZmenPrijmu;
    await klepni(tester, kontrola('brzdy'));
    expect(zdroj.pocetZmenPrijmu, zmen);
    expect(postup(tester), '10 / 10');
  });

  testWidgets('dokončený příjem se otevře na souhrnu a jde znovu otevřít', (
    tester,
  ) async {
    await spust(tester);
    vyplnVse('ZK-26-0001');
    zdroj.prijmy.dokonci('ZK-26-0001');
    await otevriPrijem(tester);

    expect(krok(tester), 'Krok 4 ze 4 · Souhrn');
    expect(find.byKey(const Key('dokoncit-prijem')), findsNothing);
    await tester.tap(find.text('Znovu otevřít'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otevřít'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Příjem dokončen'), findsNothing);
    expect(zdroj.prijmy.nacti('ZK-26-0001').stav, StavPrijmu.rozpracovany);
    expect(dokoncit(tester).onPressed, isNotNull);
  });

  testWidgets('nepovedené uložení se na obrazovce vrátí a ohlásí', (
    tester,
  ) async {
    await spust(tester);
    await otevriPrijem(tester);
    await pokracuj(tester);
    zdroj.ulozeniPrijmuSelze = true;

    await klepni(tester, kontrola('brzdy'));

    expect(find.text('Server neodpovídá.'), findsOneWidget);
    expect(postup(tester), '0 / 10');
  });

  testWidgets('nález z kontroly je v souhrnu i v detailu zakázky', (
    tester,
  ) async {
    await spust(tester);
    await otevriPrijem(tester);
    await pokracuj(tester);

    await klepni(
      tester,
      find.descendant(
        of: kontrola('brzdy'),
        matching: find.byTooltip('Poznámka'),
      ),
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Opotřebené destičky vpředu',
    );
    await tester.tap(find.text('Uložit'));
    await tester.pumpAndSettle();
    expect(find.text('Opotřebené destičky vpředu'), findsOneWidget);
    await klepni(tester, kontrola('brzdy'));

    await pokracuj(tester);
    expect(find.text('NÁLEZY'), findsOneWidget);
    expect(find.text('Opotřebené destičky vpředu'), findsOneWidget);

    // Detail zakázky ze seznamu.
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zakázky'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(OrdersListScreen),
        matching: find.byType(TextField),
      ),
      '2BK 9485',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();
    await naSekci(tester, 'prijem');

    // Souhrn příjmu: stav, nález s poznámkou, celý checklist sbalený.
    final souhrn = find.byKey(const Key('prijem-souhrn'));
    await tester.ensureVisible(souhrn);
    expect(
      tester.widget<Text>(find.byKey(const Key('prijem-souhrn-stav'))).data,
      startsWith('Rozpracovaný · 1/10'),
    );
    final nalezy = find.byKey(const Key('prijem-nalezy'));
    expect(
      find.descendant(of: nalezy, matching: find.text('NÁLEZY  1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: nalezy,
        matching: find.text('Opotřebené destičky vpředu'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: souhrn, matching: find.text('Pokračovat v příjmu')),
      findsOneWidget,
    );

    await klepni(tester, find.byKey(const Key('otevrit-prijem')));
    expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
  });

  testWidgets('detail: souhrn dokončeného příjmu - dezén, STK, checklist', (
    tester,
  ) async {
    await spust(tester);
    vyplnVse('ZK-26-0001');
    zdroj.prijmy.zmen(
      'ZK-26-0001',
      'brzdy',
      ZmenaPolozky.poznamka('Destičky na hraně'),
    );
    zdroj.prijmy.dokonci('ZK-26-0001');
    await tester.enterText(
      find.descendant(
        of: find.byType(OrdersListScreen),
        matching: find.byType(TextField),
      ),
      '2BK 9485',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();
    await naSekci(tester, 'prijem');

    final souhrn = find.byKey(const Key('prijem-souhrn'));
    await tester.ensureVisible(souhrn);
    expect(
      tester.widget<Text>(find.byKey(const Key('prijem-souhrn-stav'))).data,
      startsWith('Dokončen'),
    );
    Finder v(String klic, String text) =>
        find.descendant(of: find.byKey(Key(klic)), matching: find.text(text));
    expect(v('prijem-nalezy', 'Destičky na hraně'), findsOneWidget);
    expect(find.byKey(const Key('prijem-dezen')), findsOneWidget);
    expect(v('prijem-stk', 'do 31. 5. 2027'), findsOneWidget);
    expect(
      find.descendant(of: souhrn, matching: find.text('Otevřít příjem')),
      findsOneWidget,
    );
    // Checklist je sbalený, rozbalí se klepnutím.
    expect(find.text('Kontrola osvětlení: přední, zadní, SPZ'), findsNothing);
    await klepni(tester, find.byKey(const Key('prijem-checklist')));
    expect(find.text('Kontrola osvětlení: přední, zadní, SPZ'), findsOneWidget);
  });

  testWidgets('na tabletu jsou kroky vlevo a jde na ně klepnout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await spust(tester);
    await otevriPrijem(tester);

    for (final k in KrokPrijmu.values) {
      expect(find.byKey(Key('prijem-krok-${k.name}')), findsOneWidget);
    }
    // Pruh s krokem je jen na telefonu - na tabletu je seznam kroků.
    expect(find.byKey(const Key('prijem-krok')), findsNothing);

    await tester.tap(find.byKey(const Key('prijem-krok-kontrola')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('prijem-postup')), findsOneWidget);
  });

  testWidgets('po naskenování se ukáže karta k potvrzení, ne rovnou průvodce', (
    tester,
  ) async {
    await spust(tester);
    await tester.tap(find.text('Vozidlo'));
    await tester.pumpAndSettle();

    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(VozidloScreen)),
    );
    kontejner.read(otevritJedineVozidloProvider.notifier).state = true;
    kontejner.read(dotazVozidlaProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    // U stejných modelů nebo po přeregistraci SPZ se hodí podívat, že je
    // to opravdu ten vůz - průvodce se neotevře sám.
    expect(find.byType(PrijemZakazkyScreen), findsNothing);
    expect(find.byType(IdentifikaceKarta), findsOneWidget);
    expect(find.text('Nalezena otevřená zakázka'), findsOneWidget);
    expect(find.text('NASKENOVÁNO · SPZ'), findsOneWidget);
    expect(find.text('WBATEST0000000001'), findsOneWidget);
  });

  testWidgets('rozpracovaný příjem karta řekne a nabídne pokračovat', (
    tester,
  ) async {
    await spust(tester);
    zdroj.prijmy.zmen('ZK-26-0001', 'brzdy', ZmenaPolozky.splneno(true));
    await tester.tap(find.text('Vozidlo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(VozidloScreen),
        matching: find.byType(TextField),
      ),
      '2bk 94',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.textContaining('Příjem rozpracovaný'), findsOneWidget);
    expect(find.text('Pokračovat v příjmu'), findsOneWidget);
    expect(find.text('ZADÁNO RUČNĚ'), findsOneWidget);
  });

  testWidgets('Není to ono vymaže hledání a znovu otevře skener', (
    tester,
  ) async {
    await spust(tester);
    await tester.tap(find.text('Vozidlo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(VozidloScreen),
        matching: find.byType(TextField),
      ),
      '2bk 94',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.byKey(const Key('neni-to-ono')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('neni-to-ono')));
    // Ne pumpAndSettle - kamera se v testu nespustí a kolečko by se točilo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SkenerScreen), findsOneWidget);
    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(SkenerScreen)),
    );
    expect(kontejner.read(dotazVozidlaProvider), isEmpty);
  });

  test('počet nalezených zakázek česky', () {
    expect(pocetOtevrenychZakazek(2), 'Nalezeny 2 otevřené zakázky');
    expect(pocetOtevrenychZakazek(5), 'Nalezeno 5 otevřených zakázek');
  });
}
