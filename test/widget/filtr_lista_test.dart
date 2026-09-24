import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_filter.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/filtr_lista.dart';

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
              heliosStatus: 'Zpracováváno',
              folder: const {'code': '10026', 'label': 'BMW BSL'},
            ),
            buildOrderDto(
              id: 'ZK-26-0002',
              licensePlate: '2SC 9014',
              heliosStatus: 'K fakturaci',
              folder: const {'code': '16877', 'label': 'MOT BSL'},
            ),
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

  Finder vListe(Finder finder) =>
      find.descendant(of: find.byType(FiltrLista), matching: finder);

  /// Lišta se na telefonu posouvá do strany - filtr musí být vidět.
  Future<void> klepni(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('filtr pořadače zúží seznam', (tester) async {
    await prihlas(tester);

    await klepni(tester, vListe(find.text('Pořadač')));
    await tester.tap(find.text('MOT BSL').last);
    await tester.pumpAndSettle();

    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);
  });

  testWidgets('filtr stavu z Heliosu zúží seznam', (tester) async {
    await prihlas(tester);

    await klepni(tester, vListe(find.byType(DropdownButton<String?>)).at(2));
    await tester.tap(find.text('K fakturaci').last);
    await tester.pumpAndSettle();

    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);
  });

  testWidgets('vybrané řazení svítí v liště to, podle kterého se řadí', (
    tester,
  ) async {
    await prihlas(tester);

    // Výchozí je datum přijetí - dřív tu kvůli posunu položek svítil
    // „Termín dokončení".
    expect(vListe(find.text('Řadit: Datum přijetí')), findsOneWidget);

    await klepni(tester, vListe(find.byType(DropdownButton<OrderSort?>)));
    await tester.tap(find.text('Datum ukončení').last);
    await tester.pumpAndSettle();

    expect(vListe(find.text('Řadit: Datum ukončení')), findsOneWidget);
  });
}
