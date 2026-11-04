import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/kod_vozidla.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/prijem.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_zakazky_screen.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/vozidla/domain/entities/vozidlo.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/screens/karta_vozidla_screen.dart';
import 'package:renoworkshop/src/features/vozidla/presentation/widgets/identifikace_vozidla_karta.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Záložka Vozidlo je od 4. 11. 2026 pryč: v liště je položka Vyhledat, která
/// otevře skener, a výsledek je v seznamu zakázek. Vůz a jeho kartu najde
/// hledání, příjem se zahajuje z hlavičky detailu.
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

  late FakeServiceOrderDataSource zdroj;

  /// Na dílně je jiný vůz - zkouší se vůz bez otevřené zakázky.
  Future<void> spust(
    WidgetTester tester, {
    List<KartaVozidla>? vozidla,
    List<ServiceOrderDto>? zakazky,
    Size velikost = const Size(390, 844),
  }) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    zdroj = FakeServiceOrderDataSource(
      zakazky ?? [buildOrderDto(id: 'ZK-26-0009', licensePlate: '5T1 0001')],
      archiv: [ukoncena],
      vozidla: vozidla ?? [vuz()],
    );
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
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  Future<void> napis(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(OrdersListScreen),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  }

  Future<void> klepni(WidgetTester tester, Finder cil) async {
    await tester.ensureVisible(cil);
    await tester.pumpAndSettle();
    await tester.tap(cil);
    await tester.pumpAndSettle();
  }

  final radekVozu = find.byKey(const Key('vozidlo-51234'));

  /// Posuvník karty vozidla - ne ten uvnitř označitelných textů.
  Finder seznamKarty() => find
      .descendant(
        of: find.byType(KartaVozidlaScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('v liště je Vyhledat místo záložky Vozidlo', (tester) async {
    await spust(tester);

    expect(find.text('Zakázky'), findsWidgets);
    expect(find.text('Vyhledat'), findsOneWidget);
    expect(find.text('Vozidlo'), findsNothing);
  });

  /// Ne pumpAndSettle: kolečko kamery ve skeneru se v testu točí navždy.
  Future<void> vyhledat(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav-vyhledat')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final (popis, velikost) in const [
    ('telefon', Size(390, 844)),
    ('tablet', Size(1280, 800)),
  ]) {
    testWidgets('$popis: Vyhledat otevře skener a sken hledá v zakázkách', (
      tester,
    ) async {
      await spust(tester, velikost: velikost);
      // I z jiné záložky - výsledek je vždy v seznamu zakázek.
      await tester.tap(find.text('Nastavení'));
      await tester.pumpAndSettle();

      await vyhledat(tester);
      expect(find.byType(SkenerScreen), findsOneWidget);

      tester
          .widget<SkenerScreen>(find.byType(SkenerScreen))
          .onNalezeno(
            const KodVozidla(druh: DruhKodu.spz, hodnota: '2BK 9485'),
          );
      await tester.pumpAndSettle();

      expect(find.byType(SkenerScreen), findsNothing);
      expect(find.byType(OrdersListScreen), findsOneWidget);
      expect(find.byKey(const Key('sekce-dilna')), findsOneWidget);
      // Žádná karta navíc, ani když je vůz v evidenci jediný.
      expect(find.byType(KartaVozidlaScreen), findsNothing);
    });
  }

  testWidgets('hledání najde vůz z evidence, psaní rukou kartu neotevře', (
    tester,
  ) async {
    await spust(tester);

    await napis(tester, '2bk9485');
    await tester.ensureVisible(radekVozu);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sekce-vozidla')), findsOneWidget);
    expect(find.text('Stavby Novák s.r.o.'), findsOneWidget);
    expect(find.text('2 zakázky'), findsOneWidget);
    // I jediný výsledek zůstane v seznamu - při psaní by karta vyskočila
    // dřív, než člověk dopíše.
    expect(find.byType(KartaVozidlaScreen), findsNothing);
  });

  testWidgets('hledání bez vozu prázdnou část Vozidla neukáže', (tester) async {
    await spust(tester);

    await napis(tester, 'Novák');

    expect(find.byKey(const Key('sekce-vozidla')), findsNothing);
  });

  testWidgets(
    'karta ukáže vůz, majitele, kontakt a otevřené i ukončené zakázky',
    (tester) async {
      await spust(tester);
      await napis(tester, '2BK');
      await klepni(tester, radekVozu);

      expect(find.byType(KartaVozidlaScreen), findsOneWidget);
      expect(find.byType(IdentifikaceVozidlaKarta), findsOneWidget);
      expect(find.text('Nalezeno vozidlo · 2 zakázky'), findsOneWidget);
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
    await spust(tester);
    await napis(tester, '2BK');
    await klepni(tester, radekVozu);

    final ukoncenaKarta = find.widgetWithText(OrderCard, 'Ukončeno');
    await tester.scrollUntilVisible(
      ukoncenaKarta,
      300,
      scrollable: seznamKarty(),
    );
    // Celou - scrollUntilVisible skončí u prvního kousku a klepnutí do
    // středu karty by skončilo pod okrajem obrazovky.
    await klepni(tester, ukoncenaKarta);

    // Detail zakázky, ne hláška - karta vozidla ukazuje hlavně staré
    // zakázky a ty nejsou v seznamu dílny.
    expect(find.textContaining('nebyla nalezena'), findsNothing);
    expect(find.byType(OrderDetailScreen), findsOneWidget);
  });

  Future<void> naskenuj(WidgetTester tester, KodVozidla kod) async {
    await vyhledat(tester);
    tester.widget<SkenerScreen>(find.byType(SkenerScreen)).onNalezeno(kod);
    await tester.pumpAndSettle();
  }

  testWidgets('sken jen hledá: jediná zakázka se sama neotevře', (
    tester,
  ) async {
    await spust(tester, zakazky: [rozdelana]);

    await naskenuj(
      tester,
      const KodVozidla(druh: DruhKodu.spz, hodnota: '2BK 9485'),
    );

    expect(find.byType(OrderDetailScreen), findsNothing);
    expect(find.byType(OrderCard), findsWidgets);
  });

  testWidgets('sken obálky jen hledá: najde její zakázku v seznamu', (
    tester,
  ) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(
          id: 'ZK-26-0005',
          licensePlate: '7AB 1234',
          keyEnvelope: {'code': 'KBSL-023', 'color': null},
        ),
        buildOrderDto(id: 'ZK-26-0006', licensePlate: '8CD 5678'),
      ],
    );

    await naskenuj(
      tester,
      const KodVozidla(druh: DruhKodu.obalka, hodnota: 'KBSL-023'),
    );

    expect(find.byType(OrderDetailScreen), findsNothing);
    expect(find.text('7AB 1234'), findsOneWidget);
    expect(find.text('8CD 5678'), findsNothing);
  });

  testWidgets('na tabletu se karta vozu otevře přes celou obrazovku', (
    tester,
  ) async {
    await spust(tester, velikost: const Size(1280, 800));
    await napis(tester, '2BK');
    await klepni(tester, radekVozu);

    expect(find.byType(IdentifikaceVozidlaKarta), findsOneWidget);
    expect(find.byType(OrdersListScreen), findsNothing);

    await tester.tap(find.byTooltip('Zpět'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersListScreen), findsOneWidget);
  });

  group('detail zakázky', () {
    testWidgets('odkaz Karta vozu otevře kartu', (tester) async {
      await spust(
        tester,
        zakazky: [
          buildOrderDto(
            id: 'ZK-26-0009',
            licensePlate: '5T1 0001',
            vehicleId: 51234,
          ),
        ],
      );
      await tester.tap(find.text('5T1 0001'));
      await tester.pumpAndSettle();

      await klepni(tester, find.byKey(const Key('karta-vozu')));

      expect(find.byType(KartaVozidlaScreen), findsOneWidget);
    });

    testWidgets('zakázka bez vozu v evidenci odkaz nemá', (tester) async {
      await spust(tester);
      await tester.tap(find.text('5T1 0001'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('karta-vozu')), findsNothing);
    });

    final prijemZakazky = find.byKey(const Key('prijem-hlavicka'));

    testWidgets('Příjem zakázky v hlavičce otevře průvodce', (tester) async {
      await spust(tester);
      await tester.tap(find.text('5T1 0001'));
      await tester.pumpAndSettle();

      await klepni(tester, prijemZakazky);

      expect(find.byType(PrijemZakazkyScreen), findsOneWidget);
    });

    testWidgets('rozpracovaný příjem jde z hlavičky otevřít dál', (
      tester,
    ) async {
      await spust(tester);
      zdroj.prijmy.zmen('ZK-26-0009', 'brzdy', ZmenaPolozky.splneno(true));
      await tester.tap(find.text('5T1 0001'));
      await tester.pumpAndSettle();

      expect(prijemZakazky, findsOneWidget);
    });

    testWidgets('ukončená zakázka tlačítko Příjem zakázky nemá', (
      tester,
    ) async {
      await spust(
        tester,
        zakazky: [
          buildOrderDto(
            id: 'ZK-26-0009',
            licensePlate: '5T1 0001',
            isActive: false,
          ),
        ],
      );
      await tester.tap(find.text('5T1 0001'));
      await tester.pumpAndSettle();

      expect(prijemZakazky, findsNothing);
    });
  });

  testWidgets('skener ze seznamu zakázek nemá Zadat ručně', (tester) async {
    final semantika = tester.ensureSemantics();
    await spust(tester);

    await tester.tap(find.bySemanticsLabel('Načíst VIN nebo SPZ fotoaparátem'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Pole hledání zakázek je vidět hned po zavření - tlačítko je navíc.
    expect(find.byType(SkenerScreen), findsOneWidget);
    expect(find.byKey(const Key('skener-rucne')), findsNothing);
    semantika.dispose();
  });
}
