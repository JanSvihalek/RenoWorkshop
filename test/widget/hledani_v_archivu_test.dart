import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Hledání v seznamu zakázek prohledá samo i archiv: kdo hledá zpětně,
/// často neví, jestli je zakázka ještě na dílně. Dřív to byl drobný odkaz
/// pod polem, který skoro nikdo nenašel.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<void> spust(WidgetTester tester) async {
    final zdroj = FakeServiceOrderDataSource(
      [buildOrderDto(id: 'ZK-26-0001', licensePlate: '8AB 4721')],
      archiv: [
        // Tentýž vůz byl na dílně už loni.
        buildOrderDto(
          id: 'ZK-25-0100',
          licensePlate: '8AB 4721',
          heliosStatus: 'Ukončeno',
        ),
      ],
    );
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

  Future<void> hledej(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  }

  testWidgets('najde zakázku na dílně i starší v archivu, každou jednou', (
    tester,
  ) async {
    await spust(tester);
    await hledej(tester, '8AB 4721');

    expect(find.text('OTEVŘENÉ · 1'), findsOneWidget);
    // Server vrátí i rozdělanou zakázku - v archivu se znovu neukáže.
    expect(find.text('UKONČENÉ · 1'), findsOneWidget);
    expect(find.byType(OrderCard), findsNWidgets(2));
    expect(find.text('ZK-25-0100'), findsOneWidget);
  });

  testWidgets('zakázka z archivu se otevře v detailu', (tester) async {
    await spust(tester);
    await hledej(tester, '8AB 4721');

    await tester.tap(find.text('ZK-25-0100'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.textContaining('nebyla nalezena'), findsNothing);
  });

  testWidgets('krátký dotaz archiv nehledá', (tester) async {
    await spust(tester);
    await hledej(tester, '8A');

    expect(find.byKey(const Key('sekce-archiv')), findsNothing);
    expect(find.text('ZK-25-0100'), findsNothing);
  });

  testWidgets('smazání hledání vrátí obyčejný seznam', (tester) async {
    await spust(tester);
    await hledej(tester, '8AB 4721');
    expect(find.byKey(const Key('sekce-archiv')), findsOneWidget);

    await hledej(tester, '');

    expect(find.byKey(const Key('sekce-archiv')), findsNothing);
    expect(find.byKey(const Key('sekce-dilna')), findsNothing);
    expect(find.text('ZK-25-0100'), findsNothing);
  });
}
