import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/features/settings/presentation/screens/settings_screen.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  const dlouheJmeno = 'Bc. Jaroslava Nováková-Dvořáčková';

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
              mechanicName: 'Jan Dvořák',
            ),
            buildOrderDto(
              id: 'ZK-26-0002',
              licensePlate: '2SC 9014',
              mechanicName: 'Eva Malá',
            ),
            buildOrderDto(
              id: 'ZK-26-0003',
              licensePlate: '5T1 0001',
              mechanicName: dlouheJmeno,
            ),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  Future<void> vyberZodpovednou(WidgetTester tester, String jmeno) async {
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    // Nastavení je delší než obrazovka a seznam je líný - výchozí filtr
    // se mimo obrazovku vůbec nepostaví.
    await tester.scrollUntilVisible(
      find.text('Zodpovídá'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final vyber = find
        .ancestor(of: find.text('Zodpovídá'), matching: find.byType(Row))
        .first;
    final rozbalovaci = find.descendant(
      of: vyber,
      matching: find.byType(DropdownButton<String?>),
    );
    // Nastavení je delší než obrazovka - výchozí filtr může být pod okrajem.
    await tester.ensureVisible(rozbalovaci);
    await tester.pumpAndSettle();
    await tester.tap(rozbalovaci);
    await tester.pumpAndSettle();
    await tester.tap(find.text(jmeno).last);
    await tester.pumpAndSettle();
  }

  testWidgets('výchozí zodpovědná osoba z nastavení vyfiltruje seznam', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    expect(find.text('8AB 4721'), findsOneWidget);

    await vyberZodpovednou(tester, 'Eva Malá');
    await tester.tap(find.text('Zakázky'));
    await tester.pumpAndSettle();

    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);
  });

  testWidgets('dlouhé jméno se na úzkém telefonu vejde', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Sbírají se všechna přetečení a hlídá se jen výběr v nastavení.
    // Testovací písmo má všechny znaky stejně široké, takže na 360 px
    // přetéká i jinde, kde by skutečné písmo nejspíš vyšlo - to tenhle
    // test neřeší.
    // Popis se ukládá hned - později už prvky, na které odkazuje, neexistují.
    final chyby = <String>[];
    final puvodni = FlutterError.onError;
    FlutterError.onError = (chyba) => chyby.add(chyba.toString());
    addTearDown(() => FlutterError.onError = puvodni);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await vyberZodpovednou(tester, dlouheJmeno);

    FlutterError.onError = puvodni;
    final veVyberu = chyby.where((chyba) => chyba.contains('_Vyber'));
    expect(veVyberu, isEmpty);
  });
}
