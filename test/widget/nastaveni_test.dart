import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/stav_serveru.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;
  late PametoveNastaveni uloziste;

  Future<void> spust(WidgetTester tester, {bool serverOdpovida = true}) async {
    zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')])
      ..serverOdpovida = serverOdpovida;
    uloziste = PametoveNastaveni();
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
          nastaveniUlozisteProvider.overrideWithValue(uloziste),
          pouzivaApiProvider.overrideWithValue(true),
          verzeAplikaceProvider.overrideWith((ref) async => '1.2.0 (80)'),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  Future<void> naNastaveni(WidgetTester tester) async {
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('nastaveni-stav-serveru')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('u uživatele není role, zdroj dat je Helios, server připojen', (
    tester,
  ) async {
    await spust(tester);
    await naNastaveni(tester);

    expect(find.text('Mechanik'), findsNothing);
    expect(find.text('Helios Data'), findsOneWidget);
    expect(find.text('Připojeno'), findsOneWidget);
    expect(find.text('1.2.0 (80)'), findsOneWidget);
  });

  testWidgets('nedostupný server poradí wi-fi a klepnutím zkusí znovu', (
    tester,
  ) async {
    await spust(tester, serverOdpovida: false);
    await naNastaveni(tester);

    expect(find.text('Nedostupný'), findsOneWidget);
    expect(find.textContaining('RenPriv, ISPA nebo ISPI'), findsOneWidget);

    zdroj.serverOdpovida = true;
    await tester.tap(find.byKey(const Key('nastaveni-stav-serveru')));
    await tester.pumpAndSettle();

    expect(find.text('Připojeno'), findsOneWidget);
    expect(find.textContaining('RenPriv'), findsNothing);
  });

  testWidgets('vzhled jde přepnout z hlavičky zakázek', (tester) async {
    await spust(tester);

    await tester.tap(find.byKey(const Key('menu-uzivatele')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vzhled-tmavy')));
    await tester.pumpAndSettle();

    expect(uloziste.nacti().vzhled, RezimVzhledu.tmavy);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
