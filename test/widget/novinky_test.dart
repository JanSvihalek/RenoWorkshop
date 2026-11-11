import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/novinky/novinky.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Okno „Co je nového" - stejně jako na webu: jen neviděné novinky, jednou
/// za člověka (pamatuje si to účet).
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  final novinky = [
    Novinka(
      id: 'n3',
      datum: DateTime(2026, 11, 11),
      nadpis: 'Hotové závady jsou zelené',
      text: 'Fajfka.',
    ),
    Novinka(
      id: 'n2',
      datum: DateTime(2026, 11, 8),
      nadpis: 'Zahájit a Dokončit',
      text: 'U závad.',
    ),
    Novinka(
      id: 'n1',
      datum: DateTime(2026, 11, 1),
      nadpis: 'Stará novinka',
      text: 'Dávno.',
    ),
  ];

  late FakeServiceOrderDataSource zdroj;

  Future<void> spust(WidgetTester tester, {String? videl}) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..novinky = novinky
      ..nastaveniUctu = {'newsSeen': ?videl};
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
          dnesProvider.overrideWithValue(DateTime(2026, 11, 11)),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  test('nové jsou jen novější než viděná, nováček dostane jen poslední', () {
    List<String> nove(String? videl) => [
      for (final n in noveNovinky(novinky, videl)) n.id,
    ];
    expect(nove('n1'), ['n3', 'n2']);
    expect(nove('n3'), isEmpty);
    expect(nove(null), ['n3']);
    expect(nove('smazana'), ['n3']);
    expect(noveNovinky(const [], null), isEmpty);
  });

  testWidgets('po přihlášení ukáže neviděné a poznamená si nejnovější', (
    tester,
  ) async {
    await spust(tester, videl: 'n1');

    expect(find.byKey(const Key('okno-novinek')), findsOneWidget);
    expect(find.text('Hotové závady jsou zelené'), findsOneWidget);
    expect(find.text('Zahájit a Dokončit'), findsOneWidget);
    expect(find.text('Stará novinka'), findsNothing);

    await tester.tap(find.byKey(const Key('novinky-rozumim')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('okno-novinek')), findsNothing);
    expect(zdroj.nastaveniUctu['newsSeen'], 'n3');
  });

  testWidgets('kdo všechno viděl, okno nedostane; v Nastavení jde otevřít', (
    tester,
  ) async {
    await spust(tester, videl: 'n3');
    expect(find.byKey(const Key('okno-novinek')), findsNothing);

    await tester.tap(find.text('Nastavení').first);
    await tester.pumpAndSettle();
    final tlacitko = find.byKey(const Key('co-je-noveho'));
    await tester.scrollUntilVisible(
      tlacitko,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(tlacitko);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('okno-novinek')), findsOneWidget);
    expect(find.text('Stará novinka'), findsOneWidget);
  });
}
