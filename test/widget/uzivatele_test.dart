import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/moje_prava.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/uzivatele/domain/uzivatele.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Správa uživatelů v appce (Nastavení → Uživatelé, jen admin) - stejná
/// data a pravidla jako stránka Uživatelé na webu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> doNastaveni(WidgetTester tester, MojePrava prava) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..prava = prava
      ..uzivatele = [
        const UzivatelSpravy(
          email: 'petr.kucera@renocar.cz',
          jmeno: 'Petr Kučera',
          prava: {'10026': 'W'},
        ),
      ];
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
          dnesProvider.overrideWithValue(DateTime(2026, 10, 14)),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nastavení').first);
    await tester.pumpAndSettle();
  }

  test('souhrn práv po pobočkách', () {
    const poradace = [
      PoradacSpravy(kod: '1', nazev: 'BMW BSL', pobockaNazev: 'Brno'),
      PoradacSpravy(kod: '2', nazev: 'MOT BSL', pobockaNazev: 'Brno'),
      PoradacSpravy(kod: '3', nazev: 'BMW CLI', pobockaNazev: 'Čestlice'),
    ];
    String s(Map<String, String> prava) =>
        souhrnPrav(UzivatelSpravy(email: 'x@y', prava: prava), poradace);
    expect(s({'1': 'W', '2': 'W', '3': 'R'}), 'Brno: zápis · Čestlice: čtení');
    expect(s({'1': 'W'}), 'Brno: částečně');
    expect(s({}), 'Bez přístupu');
    expect(
      souhrnPrav(const UzivatelSpravy(email: 'a@b', role: 'admin'), poradace),
      'Admin · vše',
    );
  });

  testWidgets('uživatel, který není admin, správu nevidí', (tester) async {
    await doNastaveni(
      tester,
      const MojePrava(role: 'user', poradace: {'10026': 'W'}),
    );
    expect(find.byKey(const Key('nastaveni-uzivatele')), findsNothing);
  });

  testWidgets('admin změní uživateli právo k pořadači', (tester) async {
    await doNastaveni(tester, MojePrava.vse);
    await tester.ensureVisible(find.byKey(const Key('nastaveni-uzivatele')));
    await tester.tap(find.byKey(const Key('nastaveni-uzivatele')));
    await tester.pumpAndSettle();

    expect(find.text('Brno: částečně'), findsOneWidget);
    await tester.tap(find.byKey(const Key('uzivatel-petr.kucera@renocar.cz')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('pravo-16015')),
        matching: find.text('Čtení'),
      ),
    );
    await tester.pumpAndSettle();
    final (email, role, prava) = zdroj.ulozeniUzivatelu.last;
    expect(email, 'petr.kucera@renocar.cz');
    expect(role, 'user');
    expect(prava, {'10026': 'W', '16015': 'R'});
  });

  testWidgets('admin přidá uživatele e-mailem', (tester) async {
    await doNastaveni(tester, MojePrava.vse);
    await tester.ensureVisible(find.byKey(const Key('nastaveni-uzivatele')));
    await tester.tap(find.byKey(const Key('nastaveni-uzivatele')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('uzivatel-pridat')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('uzivatel-novy-email')),
      'Nova.Kolegyne@renocar.cz',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('uzivatel-novy-pridat')));
    await tester.pumpAndSettle();

    expect(zdroj.ulozeniUzivatelu.last.$1, 'nova.kolegyne@renocar.cz');
    // Rovnou detail nového uživatele.
    expect(find.byKey(const Key('uzivatel-role')), findsOneWidget);
  });
}
