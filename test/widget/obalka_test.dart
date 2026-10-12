import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Obálka s klíčem v hlavičce detailu zakázky a v příjmu: přiřadit
/// (skenerem nebo číslem), uvolnit, obálka jiné zakázky.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> otevriDetail(
    WidgetTester tester, {
    Map<String, dynamic>? obalka,
  }) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    zdroj = FakeServiceOrderDataSource([
      buildOrderDto(
        id: 'ZK-26-0001',
        licensePlate: '8AB 4721',
        keyEnvelopeBranch: 'BSL',
        keyEnvelope: obalka,
      ),
      buildOrderDto(
        id: 'ZK-26-0002',
        licensePlate: '2SC 9014',
        keyEnvelopeBranch: 'BSL',
        keyEnvelope: {'code': 'KBSL-023', 'branchName': 'Brno Slatina'},
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(const Nastaveni(skenovatPoOtevreni: false)),
          ),
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
    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();
  }

  final kolonka = find.byKey(const Key('obalka'));
  final priradit = find.byKey(const Key('obalka-priradit-hlavicka'));
  final uvolnit = find.byKey(const Key('obalka-uvolnit-hlavicka'));
  final pole = find.byKey(const Key('obalka-kod'));
  final potvrdit = find.byKey(const Key('obalka-priradit'));

  bool lzePotvrdit(WidgetTester tester) =>
      tester.widget<FilledButton>(potvrdit).onPressed != null;

  testWidgets('bez obálky je v hlavičce Přiřadit, číslo stačí napsat', (
    tester,
  ) async {
    await otevriDetail(tester);
    expect(
      find.descendant(of: kolonka, matching: find.text('OBÁLKA S KLÍČEM')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: kolonka, matching: find.text('Nepřiřazena')),
      findsOneWidget,
    );
    expect(uvolnit, findsNothing);

    await tester.tap(priradit);
    await tester.pumpAndSettle();
    expect(find.text('Obálka s klíčem'), findsOneWidget);
    // Skener obálek je po ruce - router ho detailu předává.
    expect(find.byKey(const Key('obalka-skenovat')), findsOneWidget);
    expect(find.text('Stačí číslo, předpona KBSL- se doplní.'), findsOneWidget);
    expect(lzePotvrdit(tester), isFalse);

    await tester.enterText(pole, '7');
    await tester.pump();
    expect(find.text('Přiřadí se obálka KBSL-007.'), findsOneWidget);
    await tester.tap(potvrdit);
    await tester.pumpAndSettle();

    expect(find.text('Obálka s klíčem'), findsNothing);
    expect(
      find.descendant(of: kolonka, matching: find.text('KBSL-007')),
      findsOneWidget,
    );
    expect(uvolnit, findsOneWidget);
    expect(find.text('Klíč je v obálce KBSL-007.'), findsOneWidget);
  });

  testWidgets('nesmyslné číslo se nepřiřadí', (tester) async {
    await otevriDetail(tester);
    await tester.tap(priradit);
    await tester.pumpAndSettle();

    await tester.enterText(pole, 'ABC');
    await tester.pump();
    expect(
      find.text('Tohle není kód obálky - má tvar KBSL-023.'),
      findsOneWidget,
    );
    expect(lzePotvrdit(tester), isFalse);
  });

  testWidgets('obálka jiné zakázky se přesune až po potvrzení', (tester) async {
    await otevriDetail(tester);
    await tester.tap(priradit);
    await tester.pumpAndSettle();
    await tester.enterText(pole, '23');
    await tester.pump();
    await tester.tap(potvrdit);
    await tester.pumpAndSettle();

    // Server se ptá - obálka patří jiné rozdělané zakázce.
    expect(find.text('Obálka KBSL-023'), findsOneWidget);
    expect(find.textContaining('patří zakázce ZK-26-0002'), findsOneWidget);
    expect(
      find.descendant(of: kolonka, matching: find.text('Nepřiřazena')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('obalka-prepsat')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: kolonka, matching: find.text('KBSL-023')),
      findsOneWidget,
    );
    final nalezena = await zdroj.najdiObalku('KBSL-023');
    expect(nalezena?.zakazkaId, 'ZK-26-0001');
  });

  testWidgets('obálka v evidenci není - hláška, nic se nezmění', (
    tester,
  ) async {
    await otevriDetail(tester);
    zdroj.neznameObalky = {'KBSL-150'};
    await tester.tap(priradit);
    await tester.pumpAndSettle();
    await tester.enterText(pole, '150');
    await tester.pump();
    await tester.tap(potvrdit);
    await tester.pumpAndSettle();

    expect(find.text('Obálka KBSL-150 v evidenci není.'), findsOneWidget);
    expect(
      find.descendant(of: kolonka, matching: find.text('Nepřiřazena')),
      findsOneWidget,
    );
  });

  testWidgets('obálku jde uvolnit, s potvrzením', (tester) async {
    await otevriDetail(
      tester,
      obalka: {'code': 'KBSL-011', 'branchName': 'Brno Slatina'},
    );
    expect(
      find.descendant(of: kolonka, matching: find.text('KBSL-011')),
      findsOneWidget,
    );
    expect(priradit, findsNothing);

    await tester.tap(uvolnit);
    await tester.pumpAndSettle();
    expect(find.text('Uvolnit obálku KBSL-011?'), findsOneWidget);

    // Zrušit nic nezmění.
    await tester.tap(find.text('Zrušit'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: kolonka, matching: find.text('KBSL-011')),
      findsOneWidget,
    );

    await tester.tap(uvolnit);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('obalka-uvolnit-potvrdit')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: kolonka, matching: find.text('Nepřiřazena')),
      findsOneWidget,
    );
    expect(find.text('Obálka KBSL-011 je volná.'), findsOneWidget);
  });

  testWidgets('v příjmu je obálka na začátku kontroly', (tester) async {
    await otevriDetail(tester);
    final prijem = find.byKey(const Key('otevrit-prijem'));
    await tester.ensureVisible(prijem);
    await tester.pumpAndSettle();
    await tester.tap(prijem);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prijem-krok-kontrola')));
    await tester.pumpAndSettle();

    final karta = find.byKey(const Key('obalka-karta'));
    expect(karta, findsOneWidget);
    expect(
      find.descendant(of: karta, matching: find.text('Naskenovat obálku')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('obalka-karta-rucne')));
    await tester.pumpAndSettle();
    await tester.enterText(pole, '5');
    await tester.pump();
    await tester.tap(potvrdit);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: karta, matching: find.text('KBSL-005')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('obalka-karta-uvolnit')), findsOneWidget);
  });
}
