import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/vozidlo_screen.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Úvodní záložka z nastavení: kam se aplikace otevře po přihlášení.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late PametoveNastaveni uloziste;

  Future<void> prihlas(
    WidgetTester tester, {
    required Nastaveni nastaveni,
  }) async {
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
            FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]),
          ),
          nastaveniUlozisteProvider.overrideWithValue(uloziste),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
  }

  /// Ne pumpAndSettle: kolečko kamery ve skeneru se v testu točí navždy.
  Future<void> dojed(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('bez nastavení se otevřou Zakázky', (tester) async {
    await prihlas(tester, nastaveni: const Nastaveni());
    await tester.pumpAndSettle();

    expect(find.byType(OrdersListScreen), findsOneWidget);
    expect(find.byType(VozidloScreen), findsNothing);
  });

  testWidgets('úvodní Příjem se otevře po přihlášení', (tester) async {
    await prihlas(
      tester,
      nastaveni: const Nastaveni(
        uvodniZalozka: UvodniZalozka.vozidlo,
        skenovatPoOtevreni: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VozidloScreen), findsOneWidget);
    expect(find.byType(SkenerScreen), findsNothing);
  });

  testWidgets('úvodní Vozidla se otevřou po přihlášení', (tester) async {
    await prihlas(
      tester,
      nastaveni: const Nastaveni(
        uvodniZalozka: UvodniZalozka.vozidlo,
        skenovatPoOtevreni: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VozidloScreen), findsOneWidget);
  });

  testWidgets('se skenováním po otevření naskočí rovnou skener', (
    tester,
  ) async {
    await prihlas(
      tester,
      nastaveni: const Nastaveni(uvodniZalozka: UvodniZalozka.vozidlo),
    );
    await dojed(tester);

    expect(find.byType(SkenerScreen), findsOneWidget);
  });

  testWidgets('volba v nastavení se uloží', (tester) async {
    await prihlas(tester, nastaveni: const Nastaveni());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nastavení').last);
    await tester.pumpAndSettle();

    final volba = find.descendant(
      of: find.byKey(const Key('uvodni-zalozka')),
      matching: find.text('Vozidlo'),
    );
    await tester.ensureVisible(volba);
    await tester.pumpAndSettle();
    await tester.tap(volba);
    await tester.pumpAndSettle();

    expect(uloziste.nacti().uvodniZalozka, UvodniZalozka.vozidlo);
  });
}
