import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/monitoring/domain/monitoring.dart';
import 'package:renoworkshop/src/features/monitoring/presentation/monitoring_screen.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/moje_prava.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Admin › Monitoring v appce - stejná data a sekce jako na webu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> spust(WidgetTester tester, {double sirka = 1280}) async {
    tester.view.physicalSize = Size(sirka, sirka < 600 ? 860 : 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..prava = MojePrava.vse;
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
          dnesProvider.overrideWithValue(DateTime(2026, 11, 19)),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-monitoring')));
    await tester.pumpAndSettle();
  }

  testWidgets('tablet: souhrn, období a časová osa uživatele', (tester) async {
    await spust(tester);

    expect(find.byType(MonitoringScreen), findsOneWidget);
    expect(zdroj.nacteniMonitoringu, [7]);
    expect(find.text('Aktivní uživatelé'), findsOneWidget);
    expect(find.text('z 6 účtů'), findsOneWidget);
    // Stará verze aplikace a uživatel v tabulce.
    expect(find.text('Verze aplikace'), findsWidgets);
    expect(find.text('Jiří Dvořák'), findsWidgets);

    await tester.tap(find.text('30 dní'));
    await tester.pumpAndSettle();
    expect(zdroj.nacteniMonitoringu, [7, 30]);

    await tester.tap(
      find.byKey(const Key('monitoring-uzivatel-eva.mala@example.cz')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OsaUzivateleScreen), findsOneWidget);
    expect(find.text('Zapsal stav'), findsOneWidget);
    expect(find.text('7:42–8:12'), findsOneWidget);
  });

  testWidgets('telefon: sekce pod sebou bez přetečení', (tester) async {
    await spust(tester, sirka: 380);

    expect(find.text('Lidé a návštěvy po dnech'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Poslední chyby'),
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('monitoring')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Fotku se nepodařilo uložit.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('mřížka hodin aspoň 6–18 a odpověď služby', () {
    final m = mrizkaHodin({(0, 8): (pozadavky: 10, lidi: 2)});
    expect(m.hodiny.first, 6);
    expect(m.hodiny.last, 18);
    expect(m.bunky[0][2].sila, 1);

    final p = PrehledMonitoringu.fromJson({
      'days': 1,
      'from': '2026-11-19',
      'to': '2026-11-19',
      'visitGapMinutes': 30,
      'totals': {'users': 2, 'avgMs': null, 'accounts': 3},
      'daily': [
        {
          'date': '2026-11-19',
          'users': 2,
          'visits': 3,
          'requests': 10,
          'writes': 1,
          'byClient': {'aplikace': 10},
        },
      ],
      'hours': [
        {'weekday': 3, 'hour': 9, 'requests': 10, 'users': 2},
      ],
      'users': [
        {
          'email': 'a@b',
          'name': null,
          'clients': ['web'],
          'lastAt': '2026-11-19T08:00:00',
        },
      ],
      'inactive': [],
      'actions': [
        {'label': 'Zapsal stav', 'write': true, 'count': 1, 'users': 1},
      ],
      'screens': [],
      'versions': [
        {'version': '2.6.9+1', 'users': 1},
      ],
      'errors': [
        {'source': 'klient', 'client': 'plan', 'what': 'x'},
      ],
    });
    expect(p.lidi, 2);
    expect(p.prumerMs, isNull);
    expect(p.hodiny[(3, 9)]?.pozadavky, 10);
    expect(p.uzivatele.single.zobrazeneJmeno, 'a@b');
    expect(p.akce.single.zvyraznit, isTrue);
    expect(p.nejnovejsiVerze, '2.6.9+1');
    expect(p.chyby.single.odkud, 'Plánovač');
    expect(popisKlienta(null), 'Aplikace');
  });
}
