import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/rozdelene_zakazky_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/tabulka_zakazek.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late PametoveNastaveni uloziste;

  Future<void> spust(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
    Size velikost = const Size(800, 1200),
  }) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    uloziste = PametoveNastaveni(nastaveni);
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
              buildOrderDto(
                id: 'ZK-26-0001',
                licensePlate: '2BK 9485',
                customerName: 'Petr Novák',
              ),
              buildOrderDto(
                id: 'ZK-26-0002',
                licensePlate: '8AB 4721',
                customerName: 'MIFAL SE',
              ),
            ]),
          ),
          nastaveniUlozisteProvider.overrideWithValue(uloziste),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  Future<void> naTabulku(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('zobrazeni-tabulka')));
    await tester.pumpAndSettle();
  }

  testWidgets('přepínač přepne karty na tabulku a volbu si zapamatuje', (
    tester,
  ) async {
    await spust(tester);
    expect(find.byType(OrderCard), findsNWidgets(2));
    expect(find.byType(TabulkaZakazek), findsNothing);

    await naTabulku(tester);

    expect(find.byType(TabulkaZakazek), findsOneWidget);
    expect(find.byType(OrderCard), findsNothing);
    // Sloupce a data z obou zakázek.
    expect(find.text('ZÁKAZNÍK'), findsOneWidget);
    expect(find.text('ZK-26-0001'), findsOneWidget);
    expect(find.text('MIFAL SE'), findsOneWidget);
    // Volba přežije restart aplikace.
    expect(uloziste.nacti().zobrazeniZakazek, ZobrazeniZakazek.tabulka);

    await tester.tap(find.byKey(const Key('zobrazeni-karty')));
    await tester.pumpAndSettle();
    expect(find.byType(OrderCard), findsNWidgets(2));
  });

  testWidgets('filtr platí i v tabulce', (tester) async {
    await spust(
      tester,
      nastaveni: const Nastaveni(zobrazeniZakazek: ZobrazeniZakazek.tabulka),
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(OrdersListScreen),
        matching: find.byType(TextField),
      ),
      '8AB 4721',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('ZK-26-0002'), findsOneWidget);
    expect(find.text('ZK-26-0001'), findsNothing);
  });

  testWidgets('klepnutí na řádek otevře detail přes celou obrazovku', (
    tester,
  ) async {
    await spust(tester);
    await naTabulku(tester);

    await tester.tap(find.text('ZK-26-0001'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailScreen), findsOneWidget);
    // Přes celou obrazovku - seznam pod ním není vidět.
    expect(find.byType(TabulkaZakazek), findsNothing);
  });

  testWidgets('na tabletu je tabulka místo rozděleného zobrazení', (
    tester,
  ) async {
    await spust(tester, velikost: const Size(1280, 800));
    expect(find.byType(RozdeleneZakazkyScreen), findsOneWidget);

    await naTabulku(tester);
    expect(find.byType(RozdeleneZakazkyScreen), findsNothing);
    expect(find.byType(TabulkaZakazek), findsOneWidget);

    await tester.tap(find.text('ZK-26-0001'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.byType(TabulkaZakazek), findsNothing);
  });
}
