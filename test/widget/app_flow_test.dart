import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/department_picker.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Vybere útvar z rozbalovacího seznamu v hlavičce.
Future<void> _vyberUtvar(WidgetTester tester, String polozka) async {
  await tester.tap(find.byType(DepartmentPicker));
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
              status: 'in_repair',
              utvar: '11211',
            ),
            buildOrderDto(
              id: 'ZK-26-0002',
              licensePlate: '2SC 9014',
              customerName: 'Lucie Marková',
              status: 'waiting_for_parts',
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
    expect(find.text('2 zakázky'), findsNothing);
    expect(find.textContaining('2 zakázky'), findsOneWidget);
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('filtr útvaru zúží seznam', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    await _vyberUtvar(tester, '12211 · Útvar 12211');
    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);

    await _vyberUtvar(tester, '11211 · Útvar 11211');
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsNothing);

    await _vyberUtvar(tester, 'Všechny útvary');
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('detail zakázky umí posunout stav a promítne ho do seznamu', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();

    expect(find.text('POSTUP ZAKÁZKY'), findsOneWidget);
    expect(find.text('Posunout na: Kontrola kvality'), findsOneWidget);

    await tester.tap(find.text('Posunout na: Kontrola kvality'));
    await tester.pumpAndSettle();

    expect(find.text('Posunout na: Připraveno k vyzvednutí'), findsOneWidget);

    await tester.tap(_backButton());
    await tester.pumpAndSettle();

    expect(find.text('Kontrola kvality'), findsOneWidget);
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

  testWidgets('prázdný výsledek nabídne hledání v archivu', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // Něco, co v načtené dílně není - typicky stará zakázka.
    await tester.enterText(find.byType(TextField), 'WBA99999999999999');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Žádná zakázka nevyhovuje'), findsOneWidget);
    expect(find.text('Hledat v archivu'), findsOneWidget);

    await tester.ensureVisible(find.text('Hledat v archivu'));
    await tester.tap(find.text('Hledat v archivu'));
    await tester.pumpAndSettle();

    // Archiv se ptá serveru, ne načteného seznamu.
    expect(find.text('Archiv'), findsOneWidget);
    expect(find.text('Nic se nenašlo'), findsOneWidget);
  });
}
