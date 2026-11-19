import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/monitoring/domain/logy.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/moje_prava.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Admin › Logy v appce - stejný filtr, řazení a stránkování jako web.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  Future<void> spust(WidgetTester tester, {double sirka = 400}) async {
    tester.view.physicalSize = Size(sirka, 900);
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
    // Na telefonu je záložka až za okrajem posouvací lišty.
    await tester.ensureVisible(find.byKey(const Key('admin-logy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-logy')));
    await tester.pumpAndSettle();
  }

  Future<void> naKonec(WidgetTester tester, Finder cil) =>
      tester.scrollUntilVisible(
        cil,
        800,
        scrollable: find.descendant(
          of: find.byKey(const Key('logy')),
          matching: find.byType(Scrollable),
        ),
      );

  testWidgets('přístupy: první stránka, další stránka, filtr podle uživatele', (
    tester,
  ) async {
    await spust(tester);

    final (druh, dotaz) = zdroj.dotazyLogu.single;
    expect(druh, DruhLogu.pristupy);
    expect(dotaz, {
      'from': '2026-11-13',
      'to': '2026-11-19',
      'show': 'akce',
      'sort': 'cas',
      'dir': 'desc',
      'offset': '0',
      'limit': '100',
    });
    expect(find.text('100 z 140 záznamů'), findsOneWidget);

    await naKonec(tester, find.byKey(const Key('logy-dalsi')));
    await tester.tap(find.byKey(const Key('logy-dalsi')));
    await tester.pumpAndSettle();
    expect(zdroj.dotazyLogu.last.$2['offset'], '100');

    await tester.drag(find.byKey(const Key('logy')), const Offset(0, 20000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logy-jen-akce')));
    await tester.pumpAndSettle();
    expect(zdroj.dotazyLogu.last.$2['show'], 'vse');

    // Klepnutí na jméno vyfiltruje jen toho uživatele.
    await tester.drag(find.byKey(const Key('logy')), const Offset(0, 20000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eva Malá').first);
    await tester.pumpAndSettle();
    expect(zdroj.dotazyLogu.last.$2['email'], 'eva.mala@example.cz');
    expect(zdroj.dotazyLogu.last.$2['offset'], '0');
    expect(find.text('Filtr (1)'), findsOneWidget);
  });

  testWidgets('řádek se rozbalí, chyba služby je vidět celá', (tester) async {
    await spust(tester);

    await naKonec(tester, find.byKey(const Key('log-8995')));
    await tester.tap(find.byKey(const Key('log-8995')));
    await tester.pumpAndSettle();
    expect(find.text('internal: Database timeout'), findsOneWidget);
    expect(find.text('Otevřít zakázku ZK-26-0015'), findsOneWidget);
  });

  testWidgets('filtr v okně a řazení; události mají vlastní pole', (
    tester,
  ) async {
    await spust(tester);

    await tester.tap(find.byKey(const Key('logy-filtr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logy-filtr-vysledek')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chyby služby 5xx').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logy-filtr-pouzit')));
    await tester.pumpAndSettle();
    expect(zdroj.dotazyLogu.last.$2['result'], '5xx');

    await tester.tap(find.byKey(const Key('logy-razeni')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doba').last);
    await tester.pumpAndSettle();
    expect(zdroj.dotazyLogu.last.$2['sort'], 'trvani');
    expect(zdroj.dotazyLogu.last.$2['dir'], 'desc');

    await tester.tap(find.text('Události'));
    await tester.pumpAndSettle();
    final (druh, dotaz) = zdroj.dotazyLogu.last;
    expect(druh, DruhLogu.udalosti);
    // Výsledek i Jen akce patří jen k přístupům, řazení se vrátí na čas.
    // U událostí je show volba kliknutí.
    expect(dotaz.containsKey('result'), isFalse);
    expect(dotaz['show'], 'vse');
    expect(dotaz['sort'], 'cas');
    expect(find.text('sit_nedostupna'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logy-kliky')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bez kliknutí').last);
    await tester.pumpAndSettle();
    expect(zdroj.dotazyLogu.last.$2['show'], 'bez_kliku');
  });

  test('dotaz: jen neprázdná pole daného logu', () {
    final f = FiltrLogu.vychozi(
      DateTime(2026, 11, 19, 15),
    ).copyWith(metoda: 'POST', hledat: 'x', zakazka: ' ');
    final d = f.dotaz(
      DruhLogu.pristupy,
      razeni: 'email',
      vzestupne: true,
      offset: 0,
      limit: 50,
    );
    expect(d['method'], 'POST');
    expect(d.containsKey('q'), isFalse);
    expect(d.containsKey('order'), isFalse);
    expect(d['dir'], 'asc');
    expect(f.pocet(DruhLogu.pristupy), 1);
    expect(f.pocet(DruhLogu.udalosti), 1);
    expect(f.bezFiltru().pocet(DruhLogu.pristupy), 0);
    expect(d['show'], 'akce');
    // Všechny požadavky - i automatické načítání; Zrušit filtr volbu nechá.
    final vse = f.copyWith(jenAkce: false);
    expect(
      vse.dotaz(
        DruhLogu.pristupy,
        razeni: 'cas',
        vzestupne: false,
        offset: 0,
        limit: 50,
      )['show'],
      'vse',
    );
    expect(vse.bezFiltru().jenAkce, isFalse);
    expect(vse.pocet(DruhLogu.pristupy), 1);
  });
}
