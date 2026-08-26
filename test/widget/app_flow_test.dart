import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/branch_segmented_control.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Přepínač poboček v hlavičce - jméno pobočky je i v kartách zakázek.
Finder _branchTab(String label) => find.descendant(
  of: find.byType(BranchSegmentedControl),
  matching: find.text(label),
);

/// Zpětné tlačítko detailu - ikona se liší podle platformy.
Finder _backButton() => find.byWidgetPredicate(
  (widget) =>
      widget is Icon &&
      (widget.icon == Icons.arrow_back_rounded ||
          widget.icon == Icons.arrow_back_ios_new_rounded),
);

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
              status: 'in_repair',
              utvar: '11211',
            ),
            buildOrderDto(
              id: 'ZK-26-0002',
              licensePlate: '2SC 9014',
              customerName: 'Lucie Marková',
              status: 'waiting_for_parts',
              utvar: '12211',
            ),
          ]),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  testWidgets('bez přihlášení appka skončí na login obrazovce', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('RenoWorkshop'), findsOneWidget);
    expect(find.text('Přihlásit se přes Microsoft'), findsOneWidget);
    expect(find.text('Zakázky na dílně'), findsNothing);
  });

  testWidgets('po přihlášení se zobrazí seznam zakázek dílny', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    expect(find.text('Zakázky na dílně'), findsOneWidget);
    expect(find.text('2 zakázky'), findsNothing);
    expect(find.textContaining('2 zakázky'), findsOneWidget);
    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('filtr pobočky zúží seznam', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    // Pobočky se skládají z dat, ne z pevného výčtu - v přepínači tedy
    // musí být právě ty dvě, které mají zakázky.
    expect(_branchTab('Brno'), findsOneWidget);
    expect(_branchTab('Čestlice'), findsOneWidget);

    await tester.tap(_branchTab('Čestlice'));
    await tester.pumpAndSettle();

    expect(find.text('2SC 9014'), findsOneWidget);
    expect(find.text('8AB 4721'), findsNothing);

    await tester.tap(_branchTab('Brno'));
    await tester.pumpAndSettle();

    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsNothing);

    await tester.tap(_branchTab('Vše'));
    await tester.pumpAndSettle();

    expect(find.text('8AB 4721'), findsOneWidget);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('detail zakázky umí posunout stav a promítne ho do seznamu', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();

    expect(find.text('POSTUP ZAKÁZKY'), findsOneWidget);
    expect(find.text('Posunout na: Kontrola kvality'), findsOneWidget);

    await tester.tap(find.text('Posunout na: Kontrola kvality'));
    await tester.pumpAndSettle();

    expect(find.text('Posunout na: Připraveno k vyzvednutí'), findsOneWidget);

    await tester.tap(_backButton());
    await tester.pumpAndSettle();

    expect(find.text('Kontrola kvality'), findsOneWidget);
  });
}
