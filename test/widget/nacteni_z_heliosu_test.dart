import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Tlačítko v hlavičce seznamu: poradce právě založil zakázku v Heliosu
/// a mechanik nechce čekat na pětiminutovou synchronizaci.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> spust(WidgetTester tester) async {
    zdroj = FakeServiceOrderDataSource([
      buildOrderDto(id: 'ZK-26-0001', licensePlate: '2BK 9485'),
    ]);
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
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(const Nastaveni()),
          ),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  final tlacitko = find.byKey(const Key('nacist-z-heliosu'));

  testWidgets('dotáhne novou zakázku a řekne to', (tester) async {
    await spust(tester);
    zdroj.poSynchronizaci = [
      buildOrderDto(id: 'ZK-26-0002', licensePlate: '8AB 4721'),
    ];
    expect(find.text('8AB 4721'), findsNothing);

    await tester.tap(tlacitko);
    await tester.pumpAndSettle();

    expect(zdroj.pocetSynchronizaci, 1);
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('Zakázky jsou načtené z Heliosu'), findsOneWidget);
    // Na rozdíl od hledání se nic samo neotevře.
    expect(find.byType(OrderDetailScreen), findsNothing);
  });

  testWidgets('při minutovém limitu ukáže hlášku ze služby', (tester) async {
    await spust(tester);
    zdroj.chybaSynchronizace = 'Data se právě obnovovala, zkuste to za 42 s.';

    await tester.tap(tlacitko);
    await tester.pumpAndSettle();

    expect(
      find.text('Data se právě obnovovala, zkuste to za 42 s.'),
      findsOneWidget,
    );
    expect(zdroj.pocetSynchronizaci, 0);
  });
}
