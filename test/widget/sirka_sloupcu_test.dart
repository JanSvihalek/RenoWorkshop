import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  testWidgets('šířka sloupce v nastavení: tlačítky i zápisem', (tester) async {
    late ProviderContainer kontejner;
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
        ],
        child: Consumer(
          builder: (context, ref, _) {
            kontejner = ProviderScope.containerOf(context);
            return const RenoWorkshopApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();

    final sirka = find.byKey(const Key('sloupec-sirka-model'));
    await tester.scrollUntilVisible(
      sirka,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    Map<String, int> sirky() => kontejner.read(nastaveniProvider).sloupce.sirky;

    expect(
      find.descendant(of: sirka, matching: find.text('180')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('sloupec-sirsi-model')));
    await tester.pumpAndSettle();
    expect(sirky(), {'model': 190});
    expect(find.byKey(const Key('sloupce-vychozi')), findsOneWidget);

    // Zpátky na výchozí = v nastavení nic.
    await tester.tap(find.byKey(const Key('sloupec-uzsi-model')));
    await tester.pumpAndSettle();
    expect(sirky(), isEmpty);

    // Zápis: mimo rozsah se srovná.
    await tester.tap(sirka);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sloupec-sirka-pole')), '9000');
    await tester.tap(find.byKey(const Key('sloupec-sirka-ulozit')));
    await tester.pumpAndSettle();
    expect(sirky(), {'model': 500});
    expect(
      find.descendant(of: sirka, matching: find.text('500')),
      findsOneWidget,
    );

    // Výchozí v okně.
    await tester.tap(sirka);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sloupec-sirka-vychozi')));
    await tester.pumpAndSettle();
    expect(sirky(), isEmpty);
  });
}
