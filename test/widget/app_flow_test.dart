import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/core/widgets/workshop_bottom_nav.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Vybere útvar z lišty filtrů nad seznamem.
Future<void> _vyberUtvar(WidgetTester tester, String polozka) async {
  // Útvar je první rozbalovací seznam v liště.
  await tester.tap(find.byType(DropdownButton<String?>).first);
  await tester.pumpAndSettle();
  // Vybraná položka se vykresluje i v zavřeném seznamu, proto `.last` -
  // ta v rozbalené nabídce.
  await tester.tap(find.text(polozka).last);
  await tester.pumpAndSettle();
}

/// Zpětné tlačítko detailu - ikona se liší podle platformy.
Finder _backButton() => find.byWidgetPredicate(
  (widget) =>
      widget is Icon &&
      (widget.icon == Icons.arrow_back_rounded ||
          widget.icon == Icons.arrow_back_ios_new_rounded),
);

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          PlaceholderAuthRepository(
            ssoDelay: Duration.zero,
            biometricDelay: Duration.zero,
          ),
        ),
        serviceOrderDataSourceProvider.overrideWithValue(
          FakeServiceOrderDataSource([
            buildOrderDto(
              id: 'ZK-26-0001',
              licensePlate: '8AB 4721',
              status: 'Klempířské práce',
              statusCode: 'klempirna',
              utvar: '11211',
            ),
            buildOrderDto(
              id: 'ZK-26-0002',
              licensePlate: '2SC 9014',
              customerName: 'Lucie Marková',
              status: 'Čeká na díly',
              statusCode: 'ceka_dily',
              utvar: '12211',
            ),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  testWidgets('bez přihlášení appka skončí na login obrazovce', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('RenoWorkshop'), findsOneWidget);
    expect(find.text('Přihlásit se přes Microsoft'), findsOneWidget);
    expect(find.text('Zakázky na dílně'), findsNothing);
  });

  testWidgets('po přihlášení se zobrazí seznam zakázek dílny', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    expect(find.text('Zakázky na dílně'), findsOneWidget);
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('filtr útvaru zúží seznam', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    await _vyberUtvar(tester, '12211');
    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);

    await _vyberUtvar(tester, '11211');
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsNothing);

    await _vyberUtvar(tester, 'Vše');
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('detail zakázky umí přidat stav a promítne ho do seznamu', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();

    expect(find.text('POSTUP ZAKÁZKY'), findsOneWidget);
    // Stav se přidává odkazem v kartě postupu, velké tlačítko dole zmizelo.
    expect(find.text('Přidat stav'), findsNothing);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('POSTUP ZAKÁZKY'),
          matching: find.byType(Row),
        ),
        matching: find.byKey(const Key('pridat-stav')),
      ),
      findsOneWidget,
    );

    // Stav se přidává formulářem: vyber v seznamu, volitelně poznámka,
    // potvrď. Neposouvá se o krok.
    await tester.ensureVisible(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vyberte stav'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lakovna').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'stání 4');
    await tester.tap(find.widgetWithText(FilledButton, 'Přidat'));
    await tester.pumpAndSettle();

    // Nový stav je v historii i v hlavičce detailu, poznámka u něj.
    expect(find.text('Lakovna'), findsWidgets);
    expect(find.text('stání 4'), findsOneWidget);

    // Omylem přidaný stav jde smazat.
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Smazat stav?'), findsOneWidget);
    await tester.tap(find.text('Zrušit'));
    await tester.pumpAndSettle();

    await tester.tap(_backButton());
    await tester.pumpAndSettle();

    // Na kartě konkrétně - „Lakovna" se objeví i ve filtrovacích chipech,
    // protože ten stav je nově mezi použitými.
    expect(
      find.descendant(
        of: find.byType(OrderCard),
        matching: find.text('Lakovna'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('nastavení ukáže přihlášeného a umí odhlásit', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // "Moje směna" byla ze spodní navigace odebrána.
    expect(find.text('Moje směna'), findsNothing);

    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();

    expect(find.text('Jan Dvořák'), findsOneWidget);
    expect(find.text('jan.dvorak@renocar.cz'), findsOneWidget);
    // Volby vzhledu a výchozího filtru jsou nad odhlášením.
    expect(find.text('VZHLED'), findsOneWidget);
    expect(find.text('VÝCHOZÍ FILTR'), findsOneWidget);

    // Tlačítko je až pod kartami. V líném seznamu se mimo obrazovku
    // vůbec nepostaví, takže se k němu musí odrolovat.
    await tester.scrollUntilVisible(
      find.text('Odhlásit se'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odhlásit se'));
    await tester.pumpAndSettle();

    // Odhlášení se ptá, ať se nestane omylem.
    expect(find.text('Odhlásit se?'), findsOneWidget);
    await tester.tap(find.text('Odhlásit'));
    await tester.pumpAndSettle();

    expect(find.text('Přihlásit se přes Microsoft'), findsOneWidget);
  });

  testWidgets('stažení prstem znovu načte seznam ze serveru', (tester) async {
    final zdroj = FakeServiceOrderDataSource([
      buildOrderDto(id: 'ZK-26-0001', licensePlate: '8AB 4721'),
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

    final pocetPredObnovou = zdroj.pocetNacteni;

    await tester.fling(find.text('8AB 4721'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    // Dílenský stav je sdílený, takže obnova musí sáhnout na zdroj dat
    // znovu, ne vrátit, co má appka v paměti.
    expect(zdroj.pocetNacteni, greaterThan(pocetPredObnovou));
  });

  testWidgets('prázdný výsledek řekne, že nic není ani v archivu', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // Něco, co v načtené dílně není - typicky stará zakázka.
    await tester.enterText(find.byType(TextField), 'WBA99999999999999');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Archiv se prohledá sám, bez klepnutí na tlačítko.
    expect(find.text('NA DÍLNĚ · 0'), findsOneWidget);
    expect(find.text('V archivu nic dalšího.'), findsOneWidget);
    // Zakázka založená před chvílí se dá dotáhnout z Heliosu.
    expect(find.text('Načíst nové zakázky z Heliosu'), findsOneWidget);
  });

  testWidgets('detail ukáže stav z Heliosu vedle dílenského', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();

    // Dva nezávislé pohledy na tutéž zakázku: ERP a dílna.
    expect(find.text('Zpracováváno'), findsOneWidget);
    expect(find.text('Klempířské práce'), findsWidgets);
  });

  testWidgets('archiv se hledá sám, jakmile je co hledat', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // Bez dotazu jen seznam dílny - v archivu by nebylo co hledat.
    expect(find.byKey(const Key('sekce-archiv')), findsNothing);

    await tester.enterText(find.byType(TextField).first, '8AB');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // Hledá se i když seznam něco našel: tentýž vůz mohl být na dílně
    // už dřív a ta starší zakázka je jen v archivu.
    expect(find.text('NA DÍLNĚ · 1'), findsOneWidget);
    expect(find.byKey(const Key('sekce-archiv')), findsOneWidget);
    expect(find.text('8AB 4721'), findsOneWidget);
  });

  testWidgets('filtry jsou vedle sebe nad seznamem', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // Útvar, stav, typ, zodpovídá a řazení - všechno v jedné liště,
    // ne schované pod tlačítkem.
    expect(find.text('Útvar'), findsOneWidget);
    // Dva stavy zvlášť, jako na kartě: z Heliosu a dílenský.
    expect(find.text('Stav Helios'), findsOneWidget);
    expect(find.text('Stav dílna'), findsOneWidget);
    expect(find.text('Typ'), findsOneWidget);
    expect(find.text('Zodpovídá'), findsOneWidget);
    expect(find.textContaining('Řadit'), findsOneWidget);
  });

  testWidgets('lišta záložek se při přepnutí nepřekresluje', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // Lišta je nad obrazovkami, ne v nich: při přepnutí záložky se nesmí
    // postavit znovu, jinak by přeblikla spolu s obsahem.
    final pred = tester.element(find.byType(WorkshopBottomNav));

    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    expect(find.text('VZHLED'), findsOneWidget);

    final po = tester.element(find.byType(WorkshopBottomNav));
    expect(identical(pred, po), isTrue);

    await tester.tap(find.text('Zakázky'));
    await tester.pumpAndSettle();

    expect(
      identical(tester.element(find.byType(WorkshopBottomNav)), pred),
      isTrue,
    );
    expect(find.text('8AB 4721'), findsOneWidget);
  });
}
