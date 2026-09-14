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
              insurer: const {'id': 60001, 'name': 'Kooperativa'},
              insuranceClaimNumber: '4201234567',
            ),
            buildOrderDto(id: 'ZK-26-0002', licensePlate: '2SC 9014'),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  Future<void> prihlas(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  testWidgets('pojišťovna je na kartě jen u pojistné události', (tester) async {
    await prihlas(tester);

    expect(
      find.descendant(
        of: find.widgetWithText(OrderCard, '8AB 4721'),
        matching: find.text('Kooperativa · PU 4201234567'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(OrderCard, '2SC 9014'),
        matching: find.byIcon(Icons.shield_outlined),
      ),
      findsNothing,
    );
  });

  testWidgets('detail ukáže pojišťovnu', (tester) async {
    await prihlas(tester);
    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();

    expect(find.text('POJIŠŤOVNA'), findsOneWidget);
    expect(find.text('Kooperativa'), findsOneWidget);
    expect(find.text('POJISTNÁ UDÁLOST'), findsOneWidget);
    expect(find.text('4201234567'), findsOneWidget);
  });

  testWidgets('hledání najde zakázku podle čísla pojistné události', (
    tester,
  ) async {
    await prihlas(tester);

    await tester.enterText(find.byType(TextField).first, '42012');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsNothing);
  });

  testWidgets('hledání najde zakázky podle pojišťovny', (tester) async {
    await prihlas(tester);

    await tester.enterText(find.byType(TextField).first, 'kooperativa');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsNothing);
  });
}
