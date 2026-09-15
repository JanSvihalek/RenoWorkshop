import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';
import 'package:renoworkshop/src/features/prijem/data/prijem_data_source.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/prijem.dart';
import 'package:renoworkshop/src/features/prijem/presentation/controllers/prijem_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_zakazky_screen.dart';

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

  /// Tlačítko je pod checklistem a seznam ho do té doby nepostaví.
  Future<void> naDokonceni(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('dokoncit-prijem')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PrijemZakazkyScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  String postup(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('prijem-postup'))).data!;

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

  testWidgets('příjem: najít vůz, projít checklist a dokončit', (tester) async {
    await spust(tester);
    await otevriPrijem(tester);

    expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
    expect(postup(tester), '0 / 9');
    await naDokonceni(tester);
    expect(dokoncit(tester).onPressed, isNull);
    expect(find.text('Zbývá zkontrolovat: 9'), findsOneWidget);

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

    await naDokonceni(tester);
    await tester.tap(find.byKey(const Key('dokoncit-prijem')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Příjem dokončen'),
      -300,
      scrollable: find
          .descendant(
            of: find.byType(PrijemZakazkyScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Příjem dokončen'), findsWidgets);
    expect(zdroj.prijmy.nacti('ZK-26-0001').stav, StavPrijmu.dokoncen);

    // Dokončený příjem je zamčený.
    final zmen = zdroj.pocetZmenPrijmu;
    await klepni(tester, kontrola('brzdy'));
    expect(zdroj.pocetZmenPrijmu, zmen);
    expect(postup(tester), '9 / 9');
  });

  testWidgets('dokončený příjem jde znovu otevřít', (tester) async {
    await spust(tester);
    vyplnVse('ZK-26-0001');
    zdroj.prijmy.dokonci('ZK-26-0001');
    await otevriPrijem(tester);

    expect(find.byKey(const Key('dokoncit-prijem')), findsNothing);
    await tester.tap(find.text('Znovu otevřít'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otevřít'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Příjem dokončen'), findsNothing);
    expect(zdroj.prijmy.nacti('ZK-26-0001').stav, StavPrijmu.rozpracovany);
    await naDokonceni(tester);
    expect(dokoncit(tester).onPressed, isNotNull);
  });

  testWidgets('nepovedené uložení se na obrazovce vrátí a ohlásí', (
    tester,
  ) async {
    await spust(tester);
    await otevriPrijem(tester);
    zdroj.ulozeniPrijmuSelze = true;

    await klepni(tester, kontrola('brzdy'));

    expect(find.text('Server neodpovídá.'), findsOneWidget);
    expect(postup(tester), '0 / 9');
  });

  testWidgets('poznámka z kontroly je vidět i v detailu zakázky', (
    tester,
  ) async {
    await spust(tester);
    await otevriPrijem(tester);

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
