import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/screens/fotodokumentace_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';
import 'package:renoworkshop/src/features/prijem/data/prijem_data_source.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/prijem.dart';
import 'package:renoworkshop/src/features/prijem/presentation/controllers/prijem_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_zakazky_screen.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';

import '../helpers/fake_service_order_data_source.dart';

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
    await tester.tap(find.text('Příjem'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PrijemScreen),
        matching: find.byType(TextField),
      ),
      '2bk 94',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.byType(OrderCard));
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
      zdroj.prijmy.zmen(
        orderId,
        polozka.kod,
        polozka.typ == TypKontroly.datum
            ? ZmenaPolozky.datum(DateTime(2027, 5, 31))
            : ZmenaPolozky.splneno(true),
      );
    }
  }

  testWidgets('příjem jde po krocích: vozidlo, fotky, kontrola, souhrn', (
    tester,
  ) async {
    await spust(tester);
    await otevriPrijem(tester);

    expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
    expect(krok(tester), 'KROK 1 Z 4 · VOZIDLO');
    expect(find.text('WBATEST0000000001'), findsOneWidget);
    // Na prvním kroku není kam se vracet.
    expect(find.byKey(const Key('prijem-zpet')), findsNothing);

    await pokracuj(tester);
    expect(krok(tester), 'KROK 2 Z 4 · FOTODOKUMENTACE');
    expect(find.byType(FotodokumentaceObsah), findsOneWidget);

    await pokracuj(tester);
    expect(krok(tester), 'KROK 3 Z 4 · KONTROLA');
    expect(postup(tester), '0 / 9');

    // Souhrn ukáže, co chybí, a dokončit nejde.
    await pokracuj(tester);
    expect(krok(tester), 'KROK 4 Z 4 · SOUHRN');
    expect(find.text('Chybí zkontrolovat: 9'), findsOneWidget);
    expect(dokoncit(tester).onPressed, isNull);

    // Zpět na kontrolu a vyplnit.
    await tester.tap(find.byKey(const Key('prijem-zpet')));
    await tester.pumpAndSettle();
    expect(krok(tester), 'KROK 3 Z 4 · KONTROLA');
    for (final polozka in vychoziChecklist) {
      if (polozka.typ == TypKontroly.kontrola) {
        await klepni(tester, kontrola(polozka.kod));
      }
    }
    expect(postup(tester), '8 / 9');
    // Zaškrtnutí se ukládá hned, bez tlačítka Uložit.
    expect(zdroj.prijmy.nacti('ZK-26-0001').pocetVyplnenych, 8);

    // STK se nezaškrtává, zadává se datum.
    await klepni(tester, kontrola('stk'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(postup(tester), '9 / 9');

    await pokracuj(tester);
    expect(find.text('Zkontrolováno vše (9)'), findsOneWidget);
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
    expect(postup(tester), '9 / 9');
  });

  testWidgets('dokončený příjem se otevře na souhrnu a jde znovu otevřít', (
    tester,
  ) async {
    await spust(tester);
    vyplnVse('ZK-26-0001');
    zdroj.prijmy.dokonci('ZK-26-0001');
    await otevriPrijem(tester);

    expect(krok(tester), 'KROK 4 Z 4 · SOUHRN');
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
    await pokracuj(tester, kolikrat: 2);
    zdroj.ulozeniPrijmuSelze = true;

    await klepni(tester, kontrola('brzdy'));

    expect(find.text('Server neodpovídá.'), findsOneWidget);
    expect(postup(tester), '0 / 9');
  });

  testWidgets('nález z kontroly je v souhrnu i v detailu zakázky', (
    tester,
  ) async {
    await spust(tester);
    await otevriPrijem(tester);
    await pokracuj(tester, kolikrat: 2);

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

    final karta = find.byKey(const Key('otevrit-prijem'));
    await tester.ensureVisible(karta);
    expect(
      find.descendant(
        of: karta,
        matching: find.text('Rozpracovaný · zkontrolováno 1 z 9'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: karta, matching: find.text('1 kontrola s poznámkou')),
      findsOneWidget,
    );

    await klepni(tester, karta);
    expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
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

  testWidgets('po naskenování se jediná zakázka otevře rovnou do příjmu', (
    tester,
  ) async {
    await spust(tester);
    await tester.tap(find.text('Příjem'));
    await tester.pumpAndSettle();

    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(PrijemScreen)),
    );
    kontejner.read(otevritJedinyPrijemProvider.notifier).state = true;
    kontejner.read(dotazPrijmuProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
  });
}
