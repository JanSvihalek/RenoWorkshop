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

  /// Posuvník karty vozidla - ne ten uvnitř označitelných textů.
  Finder seznamKarty() => find
      .descendant(
        of: find.byType(KartaVozidlaScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('záložka Vozidla nabídne naskenování SPZ', (tester) async {
    await naZalozkuVozidel(tester);

    expect(find.text('Vyhledat vozidlo'), findsOneWidget);
    expect(find.text('Najděte vozidlo'), findsOneWidget);
  });

  testWidgets('najde vůz bez ohledu na mezery a psaní rukou kartu neotevře', (
    tester,
  ) async {
    await naZalozkuVozidel(tester);

    await napis(tester, '2bk9485');

    expect(find.text('2BK 9485'), findsOneWidget);
    expect(find.text('Stavby Novák s.r.o.'), findsOneWidget);
    expect(find.text('2 zakázky'), findsOneWidget);
    // I jediný výsledek zůstane v seznamu - při psaní by karta vyskočila
    // dřív, než člověk dopíše.
    expect(find.byType(KartaVozidlaScreen), findsNothing);
  });

  testWidgets(
    'karta ukáže vůz, majitele, kontakt a otevřené i ukončené zakázky',
    (tester) async {
      await naZalozkuVozidel(tester);
      await napis(tester, '2BK');
      await tester.tap(find.text('BMW 320d Touring'));
      await tester.pumpAndSettle();

      expect(find.byType(KartaVozidlaScreen), findsOneWidget);
      // Karta jako identifikace v příjmu, se všemi údaji o voze.
      expect(find.byType(IdentifikaceVozidlaKarta), findsOneWidget);
      expect(find.text('Nalezeno vozidlo · 2 zakázky'), findsOneWidget);
      expect(find.text('ZADÁNO RUČNĚ'), findsOneWidget);
      expect(find.text('WBA8E9C50GK123456'), findsOneWidget);
      expect(find.text('Nafta'), findsOneWidget);
      expect(
        find.text('${NumberFormat.decimalPattern('cs_CZ').format(123456)} km'),
        findsOneWidget,
      );
      // Všechny údaje s popisky, jako na dřívější kartě vozidla.
      for (final popisek in [
        'VIN',
        'MODEL',
        'PALIVO',
        'TACHOMETR',
        'MAJITEL',
        'NÁZEV',
        'IČO',
        'ADRESA',
        'KONTAKTNÍ OSOBA',
        'JMÉNO',
      ]) {
        expect(find.text(popisek), findsOneWidget, reason: popisek);
      }
      expect(find.text('TELEFON'), findsNWidgets(2));
      expect(find.text('Stavby Novák s.r.o.'), findsOneWidget);
      expect(find.text('12345678'), findsOneWidget);
      expect(find.text('Masarykova 123/4, 60200 Brno'), findsOneWidget);
      expect(find.text('+420 777 123 456'), findsOneWidget);
      expect(find.text('Petr Řidič'), findsOneWidget);
      expect(find.text('+420 603 000 111'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ZAKÁZKY (2)'),
        300,
        scrollable: seznamKarty(),
      );
      expect(find.text('ZAKÁZKY (2)'), findsOneWidget);
    },
  );

  testWidgets('ukončená zakázka z karty vozidla se otevře', (tester) async {
    await naZalozkuVozidel(tester);
    await napis(tester, '2BK');
    await tester.tap(find.text('BMW 320d Touring'));
    await tester.pumpAndSettle();

    final ukoncenaKarta = find.widgetWithText(OrderCard, 'Ukončeno');
    await tester.scrollUntilVisible(
      ukoncenaKarta,
      300,
      scrollable: seznamKarty(),
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

  testWidgets('po naskenování se jediný vůz otevře rovnou', (tester) async {
    await naZalozkuVozidel(tester);

    // Totéž, co udělá skener: vyplní dotaz a řekne, že přišel z fotoaparátu.
    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(VyhledavaniScreen)),
    );
    kontejner.read(otevritJedineVozidloProvider.notifier).state = true;
    kontejner.read(dotazVozidlaProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    expect(find.byType(KartaVozidlaScreen), findsOneWidget);
    expect(find.text('NASKENOVÁNO'), findsOneWidget);
    // Pole převzalo naskenovanou SPZ - po návratu je vidět, co se hledalo.
    expect(find.text('2BK 9485', skipOffstage: false), findsWidgets);
  });

  testWidgets('Není to ono vrátí k hledání a otevře skener', (tester) async {
    await naZalozkuVozidel(tester);
    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(VyhledavaniScreen)),
    );
    kontejner.read(otevritJedineVozidloProvider.notifier).state = true;
    kontejner.read(dotazVozidlaProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('neni-to-ono')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('neni-to-ono')));
    // Ne pumpAndSettle: kolečko kamery ve skeneru se v testu točí navždy.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SkenerScreen), findsOneWidget);
    expect(find.byType(KartaVozidlaScreen, skipOffstage: false), findsNothing);
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
    expect(find.text('BMW 320d Touring'), findsNWidgets(2));
  });

  testWidgets('na tabletu se vůz otevře přes celou obrazovku', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await naZalozkuVozidel(tester);
    await napis(tester, '2BK');
    await tester.tap(find.text('BMW 320d Touring'));
    await tester.pumpAndSettle();

    // Stejně jako identifikace v příjmu - žádný sloupec s výsledky vedle.
    expect(find.byType(IdentifikaceVozidlaKarta), findsOneWidget);
    expect(find.byType(VyhledavaniScreen), findsNothing);

    await tester.tap(find.byTooltip('Zpět'));
    await tester.pumpAndSettle();
    expect(find.byType(VyhledavaniScreen), findsOneWidget);
  });
}
