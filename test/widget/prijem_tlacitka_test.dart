import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// „Další krok" s dlaždicí Zahájit příjem se řídí nastavením spouště
/// fotoaparátu - na tabletu vedle karty na straně palce, na telefonu pod
/// kartou s dlaždicí na straně palce.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  const zahajit = Key('zahajit-prijem-ZK-26-0001');

  Future<void> najdi(
    WidgetTester tester, {
    required Size velikost,
    required UmisteniSpouste spoust,
  }) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            PlaceholderAuthRepository(
              ssoDelay: Duration.zero,
              biometricDelay: Duration.zero,
            ),
          ),
          serviceOrderDataSourceProvider.overrideWithValue(
            FakeServiceOrderDataSource([
              buildOrderDto(id: 'ZK-26-0001', licensePlate: '2BK 9485'),
            ]),
          ),
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(
              Nastaveni(skenovatPoOtevreni: false, spoust: spoust),
            ),
          ),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Příjem').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PrijemScreen),
        matching: find.byType(TextField),
      ),
      '2BK 9485',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  Rect karta(WidgetTester tester) =>
      tester.getRect(find.byKey(const Key('karta-ZK-26-0001')));

  testWidgets('tablet, spoušť vpravo: Další krok vpravo vedle karty', (
    tester,
  ) async {
    await najdi(tester, velikost: const Size(1280, 800), spoust: .vpravo);

    expect(find.byKey(const Key('dalsi-krok-vedle')), findsOneWidget);
    expect(find.text('DALŠÍ KROK'), findsOneWidget);
    expect(find.text('Fotodokumentace'), findsOneWidget);
    expect(find.text('Zahájit příjem'), findsOneWidget);
    final dlazdice = tester.getRect(find.byKey(zahajit));
    expect(dlazdice.left, greaterThan(karta(tester).right));
    // Velká plocha pro palec, ne běžné tlačítko.
    expect(dlazdice.height, greaterThan(100));
    // „Není to ono" pod dlaždicí.
    expect(
      tester.getRect(find.byKey(const Key('neni-to-ono'))).top,
      greaterThan(dlazdice.bottom),
    );
  });

  testWidgets('tablet, spoušť vlevo: Další krok vlevo od karty', (
    tester,
  ) async {
    await najdi(tester, velikost: const Size(1280, 800), spoust: .vlevo);

    final dlazdice = tester.getRect(find.byKey(zahajit));
    expect(dlazdice.right, lessThan(karta(tester).left));
  });

  testWidgets('spoušť dole: Další krok pod kartou', (tester) async {
    await najdi(tester, velikost: const Size(1280, 800), spoust: .dole);

    expect(find.byKey(const Key('dalsi-krok-vedle')), findsNothing);
    final dlazdice = tester.getRect(find.byKey(zahajit));
    expect(dlazdice.top, greaterThan(karta(tester).bottom));
  });

  testWidgets('telefon, spoušť vlevo: dlaždice vlevo od Není to ono', (
    tester,
  ) async {
    await najdi(tester, velikost: const Size(400, 900), spoust: .vlevo);

    expect(find.byKey(const Key('dalsi-krok-vedle')), findsNothing);
    expect(
      tester.getRect(find.byKey(zahajit)).right,
      lessThan(tester.getRect(find.byKey(const Key('neni-to-ono'))).left),
    );
  });

  testWidgets('telefon, spoušť vpravo: dlaždice vpravo', (tester) async {
    await najdi(tester, velikost: const Size(400, 900), spoust: .vpravo);

    expect(
      tester.getRect(find.byKey(zahajit)).left,
      greaterThan(tester.getRect(find.byKey(const Key('neni-to-ono'))).right),
    );
  });
}
