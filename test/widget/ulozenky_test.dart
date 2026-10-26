import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/ulozenky/domain/ulozenka_pneu.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Uloženky pneu z Heliosu - karta v detailu zakázky.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  test('z API: sezóna, stav, kola s pozicí a údaji', () {
    final u = UlozenkaPneu.fromJson({
      'id': 1,
      'number': 'UCLII002727',
      'status': {'code': 2, 'label': 'Uložen'},
      'active': true,
      'season': 'winter',
      'count': 4,
      'storedAt': '2026-04-02',
      'location': 'Regál A3',
      'thisOrder': true,
      'wheels': [
        {
          'position': 'rr',
          'brand': 'NEXEN',
          'pattern': 'Nfera Sport',
          'size': '225/55 R18',
          'tread': 3.5,
          'dot': '2525',
          'speedIndex': 'Y',
          'loadIndex': 102,
        },
      ],
    });
    expect(u.zimni, isTrue);
    expect(u.stav, 'Uložen');
    expect(u.ulozeno, DateTime(2026, 4, 2));
    expect(u.kola.single.pozice, 'PZ');
    expect(u.kola.single.pneu, 'NEXEN Nfera Sport');
    expect(u.kola.single.udaje, '225/55 R18 · 102Y · DOT 2525');
  });

  testWidgets('detail zakázky: aktivní uloženka, ukončené pod rozbalením', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..ulozenky = {
        'ZK-26-0001': [
          UlozenkaPneu(
            id: 1,
            cislo: 'UCLII002727',
            stav: 'Uložen',
            zimni: true,
            pocet: 4,
            ulozeno: DateTime(2026, 4, 2),
            umisteni: 'Regál A3',
            zTetoZakazky: true,
            kola: const [
              KoloUlozenky(pozice: 'LP', vyrobce: 'NEXEN', dezen: 5.5),
              KoloUlozenky(pozice: 'PZ', vyrobce: 'NEXEN', dezen: 3.5),
            ],
          ),
          const UlozenkaPneu(
            id: 2,
            cislo: 'UCLII001000',
            stav: 'Ukončen',
            aktivni: false,
          ),
        ],
      };
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
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    final karta = find.byKey(const Key('ulozenky-pneu'));
    await tester.scrollUntilVisible(
      karta,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    Finder vKarte(String text) =>
        find.descendant(of: karta, matching: find.text(text));
    expect(vKarte('UCLII002727'), findsOneWidget);
    expect(vKarte('Zimní'), findsOneWidget);
    expect(vKarte('Z této zakázky'), findsOneWidget);
    expect(vKarte('uloženo 2. 4. 2026 · Regál A3 · 4 ks'), findsOneWidget);
    expect(vKarte('3,5 mm'), findsOneWidget);
    // Ukončená je schovaná, dokud se nerozbalí.
    expect(vKarte('UCLII001000'), findsNothing);
    await tester.tap(find.byKey(const Key('ulozenky-starsi')));
    await tester.pumpAndSettle();
    expect(vKarte('UCLII001000'), findsOneWidget);
  });
}
