import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_filter.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/plan/domain/prehled_planu.dart';
import 'package:renoworkshop/src/features/plan/presentation/plan_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/domain/nastaveni_uctu.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Nastavení na účtu: výchozí filtr, pohled plánovače, složka fotek
/// a úvodní záložka jsou stejné na webu i v telefonu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  group('převod', () {
    test('filtr zakázek tam a zpět, já = me', () {
      const n = Nastaveni(
        vychoziUtvar: '11215',
        vychoziPoradac: '10026',
        vychoziZpracovatelId: OrderFilter.ja,
      );
      final ucet = filtrZakazekDoUctu(n, null);
      expect(ucet, {
        'department': '11215',
        'folder': '10026',
        'assignee': 'me',
      });
      final zpet = filtrZakazekZUctu(const Nastaveni(), ucet);
      expect(zpet.vychoziUtvar, '11215');
      expect(zpet.vychoziZpracovatelId, OrderFilter.ja);
    });

    test('klíče z webu zůstanou, jméno zpracovatele s id', () {
      const n = Nastaveni(
        vychoziZpracovatelId: 42,
        vychoziZpracovatelJmeno: 'Petr Kučera',
      );
      expect(
        filtrZakazekDoUctu(n, {'workshopStatus': 'Lakovna', 'folder': '1'}),
        {
          'workshopStatus': 'Lakovna',
          'assignee': '42',
          'assigneeName': 'Petr Kučera',
        },
      );
      // Z webu bez jména - aspoň číslo.
      expect(
        filtrZakazekZUctu(const Nastaveni(), {
          'assignee': '7',
        }).vychoziZpracovatelJmeno,
        'č. 7',
      );
    });

    test('pohled plánovače tam a zpět', () {
      const pohled = PohledPlanu(
        pobocka: '2',
        tydnu: 2,
        filtr: OrderFilter(poradacKod: '10026', query: 'x5'),
        kodLaku: '475',
        stavPlanu: StavPlanuFiltr.bez,
      );
      final ucet = pohledDoUctu(pohled, null);
      expect(ucet, {
        'branch': '2',
        'weeks': 2,
        'filter': {'folder': '10026', 'paintCode': '475', 'planStatus': 'bez'},
      });
      final zpet = pohledZUctu(ucet, const OrderFilter(query: 'x5'));
      expect(zpet.filtr.poradacKod, '10026');
      expect(zpet.filtr.query, 'x5');
      expect(zpet.stavPlanu, StavPlanuFiltr.bez);
      expect(zpet.tydnu, 2);
    });

    test('posílají se jen změněné klíče', () {
      expect(
        zmenyNastaveni(
          {'startTab': 'zakazky', 'photoFolder': 'BSL'},
          {'startTab': 'vozidlo', 'photoFolder': 'BSL'},
        ),
        {'startTab': 'vozidlo'},
      );
    });
  });

  group('napojení', () {
    late FakeServiceOrderDataSource zdroj;
    late ProviderContainer container;

    Future<void> spust(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nastaveniUlozisteProvider.overrideWithValue(
              PametoveNastaveni(
                const Nastaveni(
                  skenovatPoOtevreni: false,
                  vychoziUtvar: '11211',
                ),
              ),
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
      container = ProviderScope.containerOf(
        tester.element(find.byType(RenoWorkshopApp)),
      );
    }

    setUp(() => zdroj = FakeServiceOrderDataSource(const []));

    testWidgets('po přihlášení převezme nastavení z účtu', (tester) async {
      zdroj.nastaveniUctu = {
        'ordersFilter': {'folder': '10026', 'workshopStatus': 'Lakovna'},
        'planner': {
          'branch': '5',
          'weeks': 2,
          'filter': {'paintCode': '475'},
        },
        'photoFolder': 'BSL',
        'startTab': 'zakazky',
      };
      await spust(tester);

      final n = container.read(nastaveniProvider);
      expect(n.vychoziPoradac, '10026');
      // Útvar z telefonu přepsal účet - na účtu žádný není.
      expect(n.vychoziUtvar, isNull);
      expect(n.slozkaFotek, 'BSL');
      expect(container.read(orderFilterProvider).poradacKod, '10026');
      expect(container.read(planPobockaProvider), '5');
      expect(container.read(planTydnuProvider), 2);
      expect(container.read(planKodLakuProvider), '475');

      // Změna v telefonu jde na účet - jen ten klíč, dílenský stav z webu
      // zůstane.
      container.read(planTydnuProvider.notifier).state = 1;
      await tester.pump(const Duration(seconds: 1));
      expect(zdroj.zmenyNastaveniUctu.last.keys, ['planner']);
      expect(
        (zdroj.nastaveniUctu['ordersFilter']! as Map)['workshopStatus'],
        'Lakovna',
      );
    });

    testWidgets('prázdný účet dostane nastavení z telefonu', (tester) async {
      await spust(tester);
      expect(zdroj.zmenyNastaveniUctu, hasLength(1));
      expect(zdroj.nastaveniUctu['ordersFilter'], {'department': '11211'});
      expect(zdroj.nastaveniUctu['startTab'], 'zakazky');
    });
  });
}
