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
            buildOrderDto(id: 'ZK-26-0001', licensePlate: '8AB 4721'),
            buildOrderDto(id: 'ZK-26-0002', licensePlate: '2SC 9014'),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  Future<void> otevriDetail(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();
  }

  Future<void> zapis(WidgetTester tester, String text) async {
    final tlacitko = find.byWidgetPredicate(
      (w) => w is Text && (w.data == 'Zapsat' || w.data == 'Upravit'),
    );
    await tester.ensureVisible(tlacitko);
    await tester.pumpAndSettle();
    await tester.tap(tlacitko);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, text);
    await tester.tap(find.text('Uložit'));
    await tester.pumpAndSettle();
  }

  /// Zpět vlastním tlačítkem v hlavičce detailu - ikona se liší podle
  /// platformy.
  Future<void> zpet(WidgetTester tester) async {
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.arrow_back_rounded ||
                w.icon == Icons.arrow_back_ios_new_rounded),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('předmět opravy se zapíše v detailu a ukáže na kartě', (
    tester,
  ) async {
    await otevriDetail(tester);
    expect(find.text('Zatím nezapsáno.'), findsOneWidget);

    await zapis(tester, 'Zadní nárazník, víko kufru');

    // Zakázka je na dílně, takže se změna propisuje přes seznam - detail
    // se musí překreslit i tak.
    expect(find.text('Zadní nárazník, víko kufru'), findsOneWidget);
    expect(find.text('Zatím nezapsáno.'), findsNothing);

    await zpet(tester);

    expect(
      find.descendant(
        of: find.widgetWithText(OrderCard, '8AB 4721'),
        matching: find.text('Zadní nárazník, víko kufru'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('smazaný předmět opravy zmizí', (tester) async {
    await otevriDetail(tester);
    await zapis(tester, 'Levé zadní světlo');
    expect(find.text('Levé zadní světlo'), findsOneWidget);

    await zapis(tester, '');

    expect(find.text('Levé zadní světlo'), findsNothing);
    expect(find.text('Zatím nezapsáno.'), findsOneWidget);
  });

  testWidgets('hledání v seznamu najde zakázku podle předmětu opravy', (
    tester,
  ) async {
    await otevriDetail(tester);
    await zapis(tester, 'Blatník přední pravý');
    await zpet(tester);

    await tester.enterText(find.byType(TextField).first, 'blatník');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsNothing);
  });
}
