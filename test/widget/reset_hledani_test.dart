import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/widgets/identifikace_karta.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/vozidla/domain/entities/vozidlo.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/karta_vozidla_screen.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/vyhledavani_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Kdo se na Příjem nebo Vozidla vrací z jiné záložky, jde na další vůz -
/// starý výsledek se má vymazat. Návrat z karty vozidla ho ale nechá.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<void> spust(WidgetTester tester) async {
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
            FakeServiceOrderDataSource(
              [buildOrderDto(id: 'ZK-26-0001', licensePlate: '2BK 9485')],
              vozidla: [
                const KartaVozidla(
                  id: 7,
                  spz: '2BK 9485',
                  vin: 'WBA8E9C50GK123456',
                  model: 'BMW 320d Touring',
                  zakazky: [],
                ),
              ],
            ),
          ),
          // Skener by se po resetu otevřel sám - tady jde jen o hledání.
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(const Nastaveni(skenovatPoOtevreni: false)),
          ),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  Future<void> napis(WidgetTester tester, Type obrazovka, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(obrazovka),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  }

  String pole(WidgetTester tester, Type obrazovka) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(obrazovka),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('Příjem po návratu z jiné záložky začíná znovu', (tester) async {
    await spust(tester);
    await tester.tap(find.text('Příjem').last);
    await tester.pumpAndSettle();
    await napis(tester, PrijemScreen, '2BK 9485');
    expect(find.byType(IdentifikaceKarta), findsOneWidget);

    await tester.tap(find.text('Zakázky').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Příjem').last);
    await tester.pumpAndSettle();

    expect(find.byType(IdentifikaceKarta), findsNothing);
    expect(pole(tester, PrijemScreen), isEmpty);
  });

  testWidgets('Vozidla po návratu z jiné záložky začínají znovu', (
    tester,
  ) async {
    await spust(tester);
    await tester.tap(find.text('Vozidla').last);
    await tester.pumpAndSettle();
    await napis(tester, VyhledavaniScreen, '2BK');
    expect(find.text('BMW 320d Touring'), findsOneWidget);

    await tester.tap(find.text('Zakázky').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vozidla').last);
    await tester.pumpAndSettle();

    expect(find.text('BMW 320d Touring'), findsNothing);
    expect(find.text('Najděte vozidlo'), findsOneWidget);
    expect(pole(tester, VyhledavaniScreen), isEmpty);
  });

  testWidgets('návrat z karty vozidla výsledek nechá', (tester) async {
    await spust(tester);
    await tester.tap(find.text('Vozidla').last);
    await tester.pumpAndSettle();
    await napis(tester, VyhledavaniScreen, '2BK');
    await tester.tap(find.text('BMW 320d Touring'));
    await tester.pumpAndSettle();
    expect(find.byType(KartaVozidlaScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Zpět'));
    await tester.pumpAndSettle();

    expect(find.text('BMW 320d Touring'), findsOneWidget);
    expect(pole(tester, VyhledavaniScreen), '2BK');
  });
}
