import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';
import 'package:renoworkshop/src/features/vozidla/domain/entities/vozidlo.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/controllers/vozidla_providers.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/karta_vozidla_screen.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/vyhledavani_screen.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/widgets/identifikace_vozidla_karta.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  final rozdelana = buildOrderDto(
    id: 'ZK-26-0001',
    licensePlate: '2BK 9485',
    heliosStatus: 'Zpracováváno',
  );
  final ukoncena = buildOrderDto(
    id: 'ZK-23-0777',
    licensePlate: '2BK 9485',
    customerName: 'Předchozí majitel s.r.o.',
    heliosStatus: 'Ukončeno',
    receivedAt: '2023-03-01T08:00:00',
  );

  KartaVozidla vuz({int id = 51234, String spz = '2BK 9485'}) => KartaVozidla(
    id: id,
    spz: spz,
    vin: 'WBA8E9C50GK123456',
    model: 'BMW 320d Touring',
    palivo: 'Nafta',
    tachometr: 123456,
    majitel: const MajitelVozidla(
      nazev: 'Stavby Novák s.r.o.',
      ico: '12345678',
      ulice: 'Masarykova 123/4',
      mesto: 'Brno',
      psc: '60200',
      telefon: '+420 777 123 456',
    ),
    kontakt: const KontaktVozidla(
      jmeno: 'Petr Řidič',
      telefon: '+420 603 000 111',
    ),
    zakazky: [rozdelana.toDomain(), ukoncena.toDomain()],
  );

  Widget buildApp({List<KartaVozidla>? vozidla}) {
    return ProviderScope(
      overrides: [
        // Skener se tu otevírá klepnutím na lupu, ne sám po přepnutí
        // záložky - to zkouší skener_po_otevreni_test.dart.
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
          FakeServiceOrderDataSource(
            [rozdelana],
            archiv: [ukoncena],
            vozidla: vozidla ?? [vuz()],
          ),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  Future<void> naZalozkuVozidel(
    WidgetTester tester, {
    List<KartaVozidla>? vozidla,
  }) async {
    await tester.pumpWidget(buildApp(vozidla: vozidla));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vozidla'));
    await tester.pumpAndSettle();
  }

  Future<void> napis(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(VyhledavaniScreen),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  }

  testWidgets('záložka Vozidla nabídne naskenování SPZ', (tester) async {
    await naZalozkuVozidel(tester);

    expect(find.text('Vyhledat vozidlo'), findsOneWidget);
    expect(find.text('Najděte vozidlo'), findsOneWidget);
  });

  testWidgets('najde vůz bez ohledu na mezery a ukáže všechny jeho údaje', (
    tester,
  ) async {
    await naZalozkuVozidel(tester);

    await napis(tester, '2bk9485');

    expect(find.byType(IdentifikaceVozidlaKarta), findsOneWidget);
    expect(find.text('2BK 9485'), findsOneWidget);
    expect(find.text('Nalezeno vozidlo · 2 zakázky'), findsOneWidget);
    expect(find.text('ZADÁNO RUČNĚ'), findsOneWidget);
    // Údaje z karty vozidla, ne jen to, co vrátí hledání.
    expect(find.text('WBA8E9C50GK123456'), findsOneWidget);
    expect(find.text('Nafta'), findsOneWidget);
    expect(
      find.text('${NumberFormat.decimalPattern('cs_CZ').format(123456)} km'),
      findsOneWidget,
    );
    expect(find.text('Stavby Novák s.r.o.'), findsOneWidget);
    expect(find.text('IČO 12345678'), findsOneWidget);
    expect(find.text('Masarykova 123/4, 60200 Brno'), findsOneWidget);
    expect(find.text('+420 777 123 456'), findsOneWidget);
    expect(find.text('Petr Řidič'), findsOneWidget);
    // Zakázky až na klepnutí - karta vozidla se sama neotevře.
    expect(find.byType(KartaVozidlaScreen), findsNothing);
    expect(find.byKey(const Key('neni-to-ono')), findsOneWidget);
  });

  testWidgets(
    'karta ukáže vůz, majitele, kontakt a otevřené i ukončené zakázky',
    (tester) async {
      await naZalozkuVozidel(tester);
      await napis(tester, '2BK');
      await tester.tap(find.byKey(const Key('otevrit-vozidlo-51234')));
      await tester.pumpAndSettle();

      expect(find.byType(KartaVozidlaScreen), findsOneWidget);
      expect(find.text('WBA8E9C50GK123456'), findsOneWidget);
      expect(find.text('Stavby Novák s.r.o.'), findsOneWidget);
      expect(find.text('Masarykova 123/4, 60200 Brno'), findsOneWidget);
      expect(find.text('Petr Řidič'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ZAKÁZKY (2)'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('ZAKÁZKY (2)'), findsOneWidget);
    },
  );

  testWidgets('ukončená zakázka z karty vozidla se otevře', (tester) async {
    await naZalozkuVozidel(tester);
    await napis(tester, '2BK');
    await tester.tap(find.byKey(const Key('otevrit-vozidlo-51234')));
    await tester.pumpAndSettle();

    final ukoncenaKarta = find.widgetWithText(OrderCard, 'Ukončeno');
    await tester.scrollUntilVisible(
      ukoncenaKarta,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    // Celou - scrollUntilVisible skončí u prvního kousku a klepnutí do
    // středu karty by skončilo pod okrajem obrazovky.
    await tester.ensureVisible(ukoncenaKarta);
    await tester.pumpAndSettle();
    await tester.tap(ukoncenaKarta);
    await tester.pumpAndSettle();

    // Detail zakázky, ne hláška - karta vozidla ukazuje hlavně staré
    // zakázky a ty nejsou v seznamu dílny.
    expect(find.textContaining('nebyla nalezena'), findsNothing);
    expect(find.text('POSTUP ZAKÁZKY'), findsOneWidget);
  });

  testWidgets('po naskenování se vůz ukáže jako karta ke kontrole', (
    tester,
  ) async {
    await naZalozkuVozidel(tester);

    // Totéž, co udělá skener: vyplní dotaz a řekne, že přišel z fotoaparátu.
    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(VyhledavaniScreen)),
    );
    kontejner.read(otevritJedineVozidloProvider.notifier).state = true;
    kontejner.read(dotazVozidlaProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    expect(find.byType(KartaVozidlaScreen), findsNothing);
    expect(find.byType(IdentifikaceVozidlaKarta), findsOneWidget);
    expect(find.text('NASKENOVÁNO'), findsOneWidget);
    // Pole převzalo naskenovanou SPZ - je vidět, co se hledalo.
    expect(find.widgetWithText(TextField, '2BK 9485'), findsOneWidget);
  });

  testWidgets('Není to ono vymaže hledání a otevře skener', (tester) async {
    await naZalozkuVozidel(tester);
    await napis(tester, '2BK 9485');

    await tester.tap(find.byKey(const Key('neni-to-ono')));
    // Ne pumpAndSettle: kolečko kamery ve skeneru se v testu točí navždy.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SkenerScreen), findsOneWidget);
    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(SkenerScreen)),
    );
    expect(kontejner.read(dotazVozidlaProvider), isEmpty);
  });

  testWidgets('víc vozidel se stejnou SPZ nabídne výběr i po naskenování', (
    tester,
  ) async {
    await naZalozkuVozidel(tester, vozidla: [vuz(id: 1), vuz(id: 2)]);

    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(VyhledavaniScreen)),
    );
    kontejner.read(otevritJedineVozidloProvider.notifier).state = true;
    kontejner.read(dotazVozidlaProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    // Přeregistrovaná SPZ: který vůz to je, musí rozhodnout člověk.
    expect(find.byType(KartaVozidlaScreen), findsNothing);
    expect(
      find.text('Nalezena 2 vozidla - vyberte to správné'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('identifikace-vozidla-1')), findsOneWidget);
    // Jedna společná cesta zpět místo „Není to ono" u každé karty.
    expect(find.byKey(const Key('neni-to-ono')), findsNothing);

    // Seznam výsledků, ne posuvník uvnitř označitelného textu (VIN).
    await tester.scrollUntilVisible(
      find.byKey(const Key('otevrit-vozidlo-2')),
      300,
      scrollable: find
          .ancestor(
            of: find.byKey(const Key('identifikace-vozidla-1')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('otevrit-vozidlo-2')));
    await tester.pumpAndSettle();

    final karta = tester.widget<KartaVozidlaScreen>(
      find.byType(KartaVozidlaScreen),
    );
    expect(karta.vozidloId, 2);
  });

  test('počet nalezených vozidel se skloňuje', () {
    expect(pocetNalezenychVozidel(1), 'Nalezeno 1 vozidlo');
    expect(pocetNalezenychVozidel(3), 'Nalezena 3 vozidla');
    expect(pocetNalezenychVozidel(5), 'Nalezeno 5 vozidel');
  });

  testWidgets('na tabletu je karta vedle výsledků, ne přes ně', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await naZalozkuVozidel(tester);
    expect(find.text('Vyberte vozidlo'), findsOneWidget);

    await napis(tester, '2BK');
    await tester.tap(find.byKey(const Key('otevrit-vozidlo-51234')));
    await tester.pumpAndSettle();

    expect(find.byType(KartaVozidlaScreen), findsOneWidget);
    // Výsledky hledání zůstaly vidět vedle karty.
    expect(find.byType(VyhledavaniScreen), findsOneWidget);
    expect(find.text('Vyberte vozidlo'), findsNothing);
  });
}
