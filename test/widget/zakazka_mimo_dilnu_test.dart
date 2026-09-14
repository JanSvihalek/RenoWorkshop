import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Widget buildApp() {
    zdroj = FakeServiceOrderDataSource(
      [buildOrderDto(id: 'ZK-26-0001', licensePlate: '8AB 4721')],
      archiv: [
        buildOrderDto(
          id: 'ZK-23-0777',
          licensePlate: '9Z9 1234',
          heliosStatus: 'Ukončeno',
        ),
      ],
    );
    return ProviderScope(
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
    );
  }

  Future<void> otevriZArchivu(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '9Z9');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('Hledat i v archivu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(OrderCard).first);
    await tester.pumpAndSettle();
  }

  testWidgets('ukončená zakázka z archivu se otevře v detailu', (tester) async {
    await otevriZArchivu(tester);

    // Dřív detail hledal jen mezi zakázkami na dílně a ukončená skončila
    // hláškou "nebyla nalezena" - přitom kvůli ní archiv vůbec existuje.
    expect(find.textContaining('nebyla nalezena'), findsNothing);
    expect(find.text('Ukončeno'), findsWidgets);
  });

  testWidgets('stav přidaný ukončené zakázce se v detailu hned ukáže', (
    tester,
  ) async {
    await otevriZArchivu(tester);

    expect(find.text('Lakovna'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pridat-stav')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vyberte stav'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lakovna').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'stojí venku');
    await tester.tap(find.widgetWithText(FilledButton, 'Přidat'));
    await tester.pumpAndSettle();

    // Zakázka není v seznamu dílny, takže se změna nepropíše přes něj -
    // detail si ji musí načíst znovu ze serveru.
    expect(find.text('stojí venku'), findsOneWidget);
  });
}
