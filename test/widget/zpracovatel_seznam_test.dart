import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/core/widgets/workshop_bottom_nav.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Zpracovatel v seznamu zakázek: na kartě a ve výchozím filtru.
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
              assignee: {'id': 501, 'name': 'Dvořák Jan'},
            ),
            buildOrderDto(
              id: 'ZK-26-0002',
              licensePlate: '2SC 9014',
              assignee: {'id': 502, 'name': 'Kříž Martin'},
            ),
            buildOrderDto(id: 'ZK-26-0003', licensePlate: '5T1 0001'),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  testWidgets('karta ukáže zpracovatele, výchozí filtr podle něj zúží', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // Jen převzaté zakázky mají na kartě řádek zpracovatele.
    expect(find.byKey(const Key('karta-zpracovatel')), findsNWidgets(2));
    expect(find.text('Kříž Martin'), findsOneWidget);

    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    final vyber = find.byKey(const Key('vychozi-zpracovatel'));
    await tester.scrollUntilVisible(
      vyber,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final rozbalovaci = find.descendant(
      of: vyber,
      matching: find.byType(DropdownButton<String?>),
    );
    await tester.ensureVisible(rozbalovaci);
    await tester.pumpAndSettle();
    await tester.tap(rozbalovaci);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nikdo').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(WorkshopBottomNav),
        matching: find.text('Zakázky'),
      ),
    );
    await tester.pumpAndSettle();

    // „Nikdo" = jen zakázka, kterou ještě nikdo nepřevzal.
    expect(find.text('5T1 0001'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);
    expect(find.text('2SC 9014'), findsNothing);
  });

  testWidgets('filtr Zpracovává nabídne přiřazené zpracovatele', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    final filtr = find.ancestor(
      of: find.text('Zpracovává'),
      matching: find.byType(DropdownButton<int?>),
    );
    await tester.ensureVisible(filtr);
    await tester.tap(filtr);
    await tester.pumpAndSettle();

    expect(find.text('Nikdo'), findsWidgets);
    expect(find.text('Dvořák Jan'), findsWidgets);
    await tester.tap(find.text('Kříž Martin').last);
    await tester.pumpAndSettle();

    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);
  });
}
