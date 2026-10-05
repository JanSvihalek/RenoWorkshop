import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_zakazky_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/widgets/identifikace_karta.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/vozidla/domain/entities/vozidlo.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/controllers/vozidla_providers.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/karta_vozidla_screen.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/vozidlo_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Záložka Vozidlo - dřív Příjem a Vozidla zvlášť. Vůz s rozdělanou
/// zakázkou ukáže kartu příjmu a pod ní vůz z evidence; hledá se i podle
/// čísla zakázky.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  final naDilne = buildOrderDto(id: 'ZK-26-0001', licensePlate: '2BK 9485');

  KartaVozidla vuz() => KartaVozidla(
    id: 51234,
    spz: '2BK 9485',
    vin: 'WBATEST0000000001',
    model: 'BMW 320d Touring',
    majitel: const MajitelVozidla(nazev: 'Stavby Novák s.r.o.'),
    zakazky: [naDilne.toDomain()],
  );

  Future<void> naVozidlo(WidgetTester tester) async {
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
            FakeServiceOrderDataSource([naDilne], vozidla: [vuz()]),
          ),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vozidlo').last);
    await tester.pumpAndSettle();
  }

  ProviderContainer kontejner(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(VozidloScreen)));

  testWidgets('lišta má místo Příjmu a Vozidel jednu záložku Vozidlo', (
    tester,
  ) async {
    await naVozidlo(tester);

    expect(find.text('Příjem'), findsNothing);
    expect(find.text('Vozidla'), findsNothing);
    expect(find.byType(VozidloScreen), findsOneWidget);
  });

  testWidgets('naskenovaný vůz na dílně: karta příjmu a pod ní vůz', (
    tester,
  ) async {
    await naVozidlo(tester);
    kontejner(tester).read(otevritJedineVozidloProvider.notifier).state = true;
    kontejner(tester).read(dotazVozidlaProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    // Karta vozu se sama neotevře - příjem se dělá tady.
    expect(find.byType(KartaVozidlaScreen), findsNothing);
    expect(find.byType(IdentifikaceKarta), findsOneWidget);
    expect(find.text('NASKENOVÁNO · SPZ'), findsOneWidget);
    expect(find.text('MAJITEL A HISTORIE VOZU'), findsOneWidget);

    // Majitel a historie o klepnutí dál.
    final radek = find.byType(RadekVozidla);
    await tester.ensureVisible(radek);
    await tester.pumpAndSettle();
    await tester.tap(radek);
    await tester.pumpAndSettle();
    expect(find.byType(KartaVozidlaScreen), findsOneWidget);
  });

  testWidgets('zahájení příjmu z karty otevře průvodce', (tester) async {
    await naVozidlo(tester);
    await tester.enterText(find.byType(TextField), '2bk94');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('zahajit-prijem-ZK-26-0001')));
    await tester.pumpAndSettle();

    expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
  });

  testWidgets('hledá i podle čísla zakázky', (tester) async {
    await naVozidlo(tester);
    await tester.enterText(find.byType(TextField), 'ZK-26-0001');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.byType(IdentifikaceKarta), findsOneWidget);
  });

  test('číslo zakázky se nemíchá s číslicemi SPZ', () {
    final zakazky = [
      buildOrderDto(id: 'Z1212608412', licensePlate: '2BK 9485').toDomain(),
      buildOrderDto(id: 'Z1212600001', licensePlate: '8AB 4721').toDomain(),
    ];
    // Celé nebo začátek čísla zakázky.
    expect(zakazkyPodleDotazu(zakazky, 'Z12126084').map((z) => z.id), [
      'Z1212608412',
    ]);
    expect(zakazkyPodleDotazu(zakazky, '1212608412'), hasLength(1));
    // Krátké číslice jsou SPZ, ne číslo zakázky.
    expect(zakazkyPodleDotazu(zakazky, '9485').map((z) => z.id), [
      'Z1212608412',
    ]);
    expect(zakazkyPodleDotazu(zakazky, '1212'), isEmpty);
  });
}
