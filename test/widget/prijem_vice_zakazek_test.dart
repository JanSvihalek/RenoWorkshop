import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_zakazky_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/widgets/identifikace_karta.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Jeden vůz se dvěma otevřenými zakázkami - třeba servis a oprava po
/// nehodě přes pojišťovnu. Technik musí vybrat, ke které přijímá.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<void> najdi(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            FakeServiceOrderDataSource([
              buildOrderDto(id: 'ZK-26-0001', licensePlate: '2BK 9485'),
              buildOrderDto(id: 'ZK-26-0002', licensePlate: '2BK 9485'),
              buildOrderDto(id: 'ZK-26-0003', licensePlate: '8AB 4721'),
            ]),
          ),
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
    await tester.tap(find.text('Příjem'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PrijemScreen),
        matching: find.byType(TextField),
      ),
      '2BK 9485',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  testWidgets('obě zakázky se ukážou pod sebou a jde vybrat', (tester) async {
    await najdi(tester);

    expect(
      find.text('Nalezeny 2 otevřené zakázky - vyberte tu správnou'),
      findsOneWidget,
    );
    expect(find.byType(IdentifikaceKarta), findsNWidgets(2));
    // Jedna společná cesta zpět místo „Není to ono" u každé karty.
    expect(find.byKey(const Key('neni-to-ono')), findsNothing);
    expect(find.byKey(const Key('nic-z-toho')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('zahajit-prijem-ZK-26-0002')),
    );
    await tester.tap(find.byKey(const Key('zahajit-prijem-ZK-26-0002')));
    await tester.pumpAndSettle();

    final pruvodce = tester.widget<PrijemZakazkyScreen>(
      find.byType(PrijemZakazkyScreen),
    );
    expect(pruvodce.orderId, 'ZK-26-0002');
  });
}
