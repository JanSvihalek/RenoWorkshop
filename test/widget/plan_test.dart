import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/plan_klempirny.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/plan/presentation/plan_karta.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Plán klempírny a lakovny v aplikaci jen ke čtení: plánuje se v portálu
/// na PC (`/plan/`), dílna vidí termín v seznamu a kartu v detailu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Map<String, dynamic> plan(
    String od,
    String do_, {
    String? kod,
    String stav = 'naplanovano',
  }) => {
    'from': od,
    'to': do_,
    'paintCode': kod,
    'note': '',
    'status': stav,
    'plannedBy': 'Jan Dvořák',
  };

  final otevrene = <Uri>[];

  Future<void> spust(
    WidgetTester tester, {
    required List<ServiceOrderDto> zakazky,
    Size velikost = const Size(1280, 1000),
    Uri? planovac,
  }) async {
    otevrene.clear();
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
          serviceOrderDataSourceProvider.overrideWithValue(
            FakeServiceOrderDataSource(zakazky),
          ),
          dnesProvider.overrideWithValue(DateTime(2026, 10, 14)),
          adresaPlanovaceProvider.overrideWithValue(planovac),
          otevritOdkazProvider.overrideWithValue((uri) async {
            otevrene.add(uri);
            return true;
          }),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  test('kód laku: ručně z plánu, jinak barva vozu z Heliosu', () {
    final p = PlanKlempirny.fromJson(plan('2026-10-12', '2026-10-12'));
    final sKodem = PlanKlempirny.fromJson(
      plan('2026-10-12', '2026-10-12', kod: ' c4p '),
    );
    final barva = BarvaVozu.zJson({'code': '475', 'name': 'Black Sapphire'});
    expect(kodLakuZakazky(sKodem, barva), 'C4P');
    expect(kodLakuZakazky(p, barva), '475');
    expect(BarvaVozu.zJson({'code': ' ', 'name': 'Bílá'}), isNull);
    expect(barva!.popis, '475 · Black Sapphire');
  });

  testWidgets('záložka Plán v aplikaci není - plánuje se v portálu', (
    tester,
  ) async {
    await spust(tester, zakazky: [buildOrderDto()]);
    expect(find.text('Zakázky'), findsWidgets);
    expect(find.text('Plán'), findsNothing);
  });

  testWidgets('naplánovaná zakázka: termín v seznamu, karta jen ke čtení', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-14', '2026-10-16'),
          vehicleColor: {'code': '475', 'name': 'Black Sapphire'},
        ),
      ],
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('karta-plan')),
        matching: find.text('Klempírna 14. 10. – 16. 10. 2026'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    final karta = find.byKey(const Key('plan-karta'));
    expect(karta, findsOneWidget);
    expect(
      find.descendant(
        of: karta,
        matching: find.text('14. 10. – 16. 10. 2026 · 3 dny'),
      ),
      findsOneWidget,
    );
    expect(find.text('NAPLÁNOVÁNO'), findsOneWidget);
    // Kód laku z barvy vozu - plán ho ručně nemá.
    expect(
      find.descendant(
        of: karta,
        matching: find.text('KÓD 475', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: karta, matching: find.text('Upravit')),
      findsNothing,
    );
    expect(
      find.descendant(of: karta, matching: find.byType(FilledButton)),
      findsNothing,
    );
  });

  testWidgets('hotový plán je v seznamu označený', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          bodyshopPlan: plan('2026-10-12', '2026-10-13', stav: 'hotovo'),
        ),
      ],
    );
    expect(
      find.text('Klempírna 12. 10. – 13. 10. 2026 · hotovo'),
      findsOneWidget,
    );
  });

  testWidgets('klempířská zakázka bez plánu: karta a proklik do plánovače', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [buildOrderDto(utvar: '11215', canPlanBodyshop: true)],
      planovac: Uri.parse('https://dilna.test/plan/'),
    );
    expect(find.byKey(const Key('karta-plan')), findsNothing);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-karta')), findsOneWidget);
    expect(find.text('Zatím nezaplánováno.'), findsOneWidget);
    await tester.tap(find.text('Zaplánovat v plánovači'));
    await tester.pump();
    expect(otevrene, [
      Uri.parse('https://dilna.test/plan/#/zakazky/ZK-26-0001'),
    ]);
  });

  testWidgets('servisní zakázka bez plánu kartu klempírny nemá', (
    tester,
  ) async {
    await spust(tester, zakazky: [buildOrderDto(utvar: '11211')]);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-karta')), findsNothing);
  });

  testWidgets('ukázková data: karta bez prokliku, není kam', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          utvar: '11215',
          canPlanBodyshop: true,
          bodyshopPlan: plan('2026-10-14', '2026-10-16'),
        ),
      ],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-karta')), findsOneWidget);
    expect(find.byKey(const Key('otevrit-planovac')), findsNothing);
  });

  testWidgets('telefon: mřížka v hlavičce otevře plánovač v prohlížeči', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [buildOrderDto()],
      planovac: Uri.parse('https://dilna.test/plan/'),
      velikost: const Size(400, 860),
    );
    expect(find.byKey(const Key('nav-aplikace')), findsNothing);
    await tester.tap(find.byKey(const Key('prepinac-aplikaci')));
    await tester.pumpAndSettle();
    expect(find.text('APLIKACE RENOWORKSHOP'), findsOneWidget);
    expect(find.text('Jste zde'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aplikace-plan')));
    await tester.pumpAndSettle();
    expect(otevrene, [Uri.parse('https://dilna.test/plan/')]);
    expect(find.text('APLIKACE RENOWORKSHOP'), findsNothing);
  });

  testWidgets('tablet: položka Aplikace v boční navigaci', (tester) async {
    await spust(
      tester,
      zakazky: [buildOrderDto()],
      planovac: Uri.parse('https://dilna.test/plan/'),
    );
    // V úzkém sloupci zakázek by mřížka zalomila nadpis - je v navigaci.
    expect(find.byKey(const Key('prepinac-aplikaci')), findsNothing);
    await tester.tap(find.byKey(const Key('nav-aplikace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aplikace-plan')));
    await tester.pumpAndSettle();
    expect(otevrene, [Uri.parse('https://dilna.test/plan/')]);
  });

  testWidgets('ukázková data, tablet: položka Aplikace není', (tester) async {
    await spust(tester, zakazky: [buildOrderDto()]);
    expect(find.byKey(const Key('nav-aplikace')), findsNothing);
  });

  testWidgets('ukázková data, telefon: mřížka v hlavičce není', (tester) async {
    await spust(
      tester,
      zakazky: [buildOrderDto()],
      velikost: const Size(400, 860),
    );
    expect(find.byKey(const Key('prepinac-aplikaci')), findsNothing);
  });
}
