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

/// Správa uživatelů v appce (záložka Admin, jen admin) - stejný vzhled,
/// data a pravidla jako stránka Uživatelé a práva na webu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> spust(
    WidgetTester tester,
    MojePrava prava, {
    double sirka = 1280,
  }) async {
    tester.view.physicalSize = Size(sirka, sirka < 600 ? 860 : 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..prava = prava
      ..uzivatele = [
        const UzivatelSpravy(
          email: 'petr.kucera@renocar.cz',
          jmeno: 'Petr Kučera',
          prava: {'10026': 'W'},
          planovac: {'1': 'R'},
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(const Nastaveni()),
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
  }

  Future<void> otevriAdmin(WidgetTester tester) async {
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
  }

  test('souhrn práv jako na webu', () {
    const poradace = [
      PoradacSpravy(kod: '1', nazev: 'BMW BSL', pobockaNazev: 'Brno'),
      PoradacSpravy(kod: '2', nazev: 'MOT BSL', pobockaNazev: 'Brno'),
      PoradacSpravy(kod: '3', nazev: 'BMW CLI', pobockaNazev: 'Čestlice'),
    ];
    const pobocky = [
      PobockaPlanu(kod: '1', nazev: 'Brno'),
      PobockaPlanu(kod: '2', nazev: 'Nupaky'),
    ];
    String s(UzivatelSpravy u) =>
        souhrnPrav(u, poradace, pobockyPlanu: pobocky);
    expect(
      s(const UzivatelSpravy(email: 'x@y', prava: {'1': 'W', '2': 'W'})),
      '2× zápis',
    );
    expect(
      s(
        const UzivatelSpravy(
          email: 'x@y',
          prava: {'1': 'W', '3': 'R'},
          planovac: {'2': 'R'},
        ),
      ),
      '1× zápis, 1× čtení · plánovač Nupaky',
    );
    expect(s(const UzivatelSpravy(email: 'x@y')), 'Žádný pořadač');
    expect(
      s(const UzivatelSpravy(email: 'a@b', role: 'admin')),
      'Vše · spravuje uživatele',
    );
    expect(inicialyUzivatele('Lang Jaroslav'), 'LJ');
    expect(inicialyUzivatele('novy@renocar.cz'), 'N');
  });

  test('filtry seznamu', () {
    final dnes = DateTime(2026, 11, 11);
    final admin = UzivatelSpravy(email: 'a@b', role: 'admin', prihlasen: dnes);
    const novy = UzivatelSpravy(email: 'n@b');
    final planuje = UzivatelSpravy(
      email: 'p@b',
      planovac: const {'1': 'R'},
      prihlasen: dnes,
    );
    expect(FiltrUzivatelu.admin.plati(admin), isTrue);
    expect(FiltrUzivatelu.admin.plati(planuje), isFalse);
    expect(FiltrUzivatelu.planovac.plati(admin), isTrue);
    expect(FiltrUzivatelu.planovac.plati(planuje), isTrue);
    expect(FiltrUzivatelu.planovac.plati(novy), isFalse);
    expect(FiltrUzivatelu.neprihlaseni.plati(novy), isTrue);
    expect(FiltrUzivatelu.neprihlaseni.plati(admin), isFalse);
  });

  testWidgets('uživatel, který není admin, záložku Admin nevidí', (
    tester,
  ) async {
    await spust(
      tester,
      const MojePrava(role: 'user', poradace: {'10026': 'W'}),
    );
    // Záložka Admin v navigaci jen pro admina.
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Nastavení'), findsWidgets);
  });

  testWidgets('tablet: seznam a detail vedle sebe, změna práva k pořadači', (
    tester,
  ) async {
    await spust(tester, MojePrava.vse);
    await otevriAdmin(tester);

    expect(find.text('Uživatelé a práva'), findsOneWidget);
    expect(find.text('1× zápis · plánovač Brno'), findsOneWidget);
    // První v seznamu je rovnou v detailu - bez přechodu na jinou obrazovku.
    expect(find.byKey(const Key('uzivatel-role')), findsOneWidget);
    expect(find.text('Petr Kučera'), findsNWidgets(2));

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
    expect(
      find.text('Uloženo · Petr Kučera · BMW CLI → čtení'),
      findsOneWidget,
    );

    // Plánovač zvlášť po pobočkách - Brno prohlíží, Nupaky začne plánovat.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('planovac-2')),
        matching: find.text('Plánovat'),
      ),
    );
    await tester.pumpAndSettle();
    expect(zdroj.ulozeniPlanovace.last, {'1': 'R', '2': 'W'});
    expect(zdroj.ulozeniUzivatelu.last.$3, {'10026': 'W', '16015': 'R'});
  });

  testWidgets('Všem nastavit: Zápis dá zápis u všech pořadačů', (tester) async {
    await spust(tester, MojePrava.vse);
    await otevriAdmin(tester);

    await tester.tap(find.byKey(const Key('vsem-W')));
    await tester.pumpAndSettle();
    expect(zdroj.ulozeniUzivatelu.last.$3, {
      '10026': 'W',
      '16877': 'W',
      '16015': 'W',
    });
  });

  testWidgets('kapacita jen s přístupem k pobočce, bez něj zase zmizí', (
    tester,
  ) async {
    await spust(tester, MojePrava.vse);
    await otevriAdmin(tester);

    // Nupaky nevidí - spínač kapacity je zašedlý a nic neuloží.
    await tester.tap(find.byKey(const Key('kapacita-2')));
    await tester.pumpAndSettle();
    expect(zdroj.ulozeniKapacity, isEmpty);

    await tester.tap(find.byKey(const Key('kapacita-1')));
    await tester.pumpAndSettle();
    expect(zdroj.ulozeniKapacity.last, {'1'});

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('planovac-1')),
        matching: find.text('–'),
      ),
    );
    await tester.pumpAndSettle();
    expect(zdroj.ulozeniPlanovace.last, isEmpty);
    expect(zdroj.ulozeniKapacity.last, isEmpty);
  });

  testWidgets('admin přidá uživatele e-mailem a rovnou ho vidí', (
    tester,
  ) async {
    await spust(tester, MojePrava.vse);
    await otevriAdmin(tester);

    await tester.enterText(
      find.byKey(const Key('uzivatel-novy-email')),
      'Nova.Kolegyne@renocar.cz',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('uzivatel-novy-pridat')));
    await tester.pumpAndSettle();

    expect(zdroj.ulozeniUzivatelu.last.$1, 'nova.kolegyne@renocar.cz');
    // V seznamu i v detailu vedle něj.
    expect(find.text('nova.kolegyne@renocar.cz'), findsNWidgets(2));
    expect(find.text('Žádný pořadač'), findsOneWidget);
  });

  testWidgets('filtr Nepřihlášení schová přihlášené', (tester) async {
    await spust(tester, MojePrava.vse);
    zdroj.uzivatele.add(
      UzivatelSpravy(
        email: 'admin@renocar.cz',
        jmeno: 'Admin Druhý',
        role: 'admin',
        prihlasen: DateTime(2026, 11, 10),
      ),
    );
    await otevriAdmin(tester);

    expect(find.byKey(const Key('uzivatel-admin@renocar.cz')), findsOneWidget);
    await tester.tap(find.byKey(const Key('filtr-neprihlaseni')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uzivatel-admin@renocar.cz')), findsNothing);
    expect(
      find.byKey(const Key('uzivatel-petr.kucera@renocar.cz')),
      findsOneWidget,
    );
  });

  testWidgets('telefon: seznam a klepnutím detail', (tester) async {
    await spust(tester, MojePrava.vse, sirka: 400);
    await otevriAdmin(tester);

    expect(find.byKey(const Key('uzivatel-role')), findsNothing);
    await tester.tap(find.byKey(const Key('uzivatel-petr.kucera@renocar.cz')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uzivatel-role')), findsOneWidget);
    expect(find.text('POŘADAČE ZAKÁZEK'), findsOneWidget);
  });
}
