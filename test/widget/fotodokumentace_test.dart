import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/order_card.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/controllers/fotky_providers.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/screens/fotodokumentace_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/ulozeni_do_zarizeni.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/ziskani_fotek.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:renoworkshop/src/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Galerie a fotoaparát bez zařízení: vrátí připravené JPEGy.
class _FalesneZiskani implements ZiskaniFotek {
  int zGalerieKusu = 2;

  static Uint8List jpeg() =>
      Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

  @override
  Future<List<Uint8List>> zGalerie(BuildContext context) async => [
    for (var i = 0; i < zGalerieKusu; i++) jpeg(),
  ];

  @override
  Future<void> foceni(
    BuildContext context, {
    required String nadpis,
    required void Function(Uint8List fotka) onFotka,
  }) async {
    onFotka(jpeg());
    onFotka(jpeg());
    onFotka(jpeg());
  }
}

/// Galerie telefonu bez zařízení: pamatuje si jména uložených fotek.
class _FalesneUlozeni implements UlozeniDoZarizeni {
  bool pristup = true;
  bool ulozeniSelze = false;
  final List<String> ulozene = [];

  @override
  Future<bool> pozadejPristup() async => pristup;

  @override
  Future<void> uloz(Uint8List jpeg, {required String nazev}) async {
    if (ulozeniSelze) {
      throw const UlozeniDoZarizeniException(
        'Fotku nejde uložit do telefonu - není v něm místo.',
      );
    }
    ulozene.add(nazev);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;
  late _FalesneUlozeni ulozeni;

  Widget buildApp({Nastaveni nastaveni = const Nastaveni()}) {
    ulozeni = _FalesneUlozeni();
    zdroj = FakeServiceOrderDataSource([
      buildOrderDto(id: 'ZK-26-0001', licensePlate: '2BK 9485'),
      buildOrderDto(id: 'ZK-26-0002', licensePlate: '8AB 4721'),
    ]);
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          PlaceholderAuthRepository(
            ssoDelay: Duration.zero,
            biometricDelay: Duration.zero,
          ),
        ),
        serviceOrderDataSourceProvider.overrideWithValue(zdroj),
        ziskaniFotekProvider.overrideWithValue(_FalesneZiskani()),
        pripravaFotkyProvider.overrideWithValue((data) async => data),
        ulozeniDoZarizeniProvider.overrideWithValue(ulozeni),
        nastaveniUlozisteProvider.overrideWithValue(
          PametoveNastaveni(nastaveni),
        ),
      ],
      child: const RenoWorkshopApp(),
    );
  }

  Future<void> naZakazky(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
  }) async {
    await tester.pumpWidget(buildApp(nastaveni: nastaveni));
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
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  Finder vKarte(String klic, Finder finder) =>
      find.descendant(of: find.byKey(Key('kategorie-$klic')), matching: finder);

  /// Karty jsou pod sebou a spodní bývají pod okrajem obrazovky.
  Future<void> klepni(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// V detailu je nad fotkami i karta příjmu - karta fotek bývá pod okrajem
  /// a seznam ji do té doby nepostaví.
  Future<Finder> naKartuFotek(WidgetTester tester) async {
    final karta = find.byKey(const Key('otevrit-fotodokumentaci'));
    await tester.scrollUntilVisible(
      karta,
      200,
      // Svislý seznam - VIN v hlavičce má vlastní vodorovný posuvník.
      scrollable: find
          .descendant(
            of: find.byType(OrderDetailScreen),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
    await tester.pumpAndSettle();
    return karta;
  }

  Future<void> otevriDetail(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
  }) async {
    await naZakazky(tester, nastaveni: nastaveni);
    await napis(tester, '2BK 9485');
    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();
  }

  Future<void> otevriZakazku(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
  }) async {
    await otevriDetail(tester, nastaveni: nastaveni);
    await klepni(tester, await naKartuFotek(tester));
  }

  Future<void> zpet(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
  }

  testWidgets('fotodokumentace se otevírá z detailu zakázky', (tester) async {
    await naZakazky(tester);
    await napis(tester, '2BK 9485');
    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();
    final karta = await naKartuFotek(tester);
    expect(
      find.descendant(of: karta, matching: find.text('Zatím bez fotek.')),
      findsOneWidget,
    );

    await klepni(tester, karta);
    expect(find.byType(FotodokumentaceScreen), findsOneWidget);
    expect(find.text('Exteriér (dokola vozu)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ostatní dokumentace'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Ostatní dokumentace'), findsOneWidget);
  });

  testWidgets('karta v detailu ukáže počet a kategorie fotek', (tester) async {
    await otevriZakazku(tester);
    await klepni(
      tester,
      vKarte('exterier', find.byTooltip('Přidat z galerie')),
    );
    await klepni(tester, vKarte('poskozeni', find.byTooltip('Vyfotit')));
    await zpet(tester);

    final karta = await naKartuFotek(tester);
    expect(
      find.descendant(
        of: karta,
        matching: find.text('5 fotek · Exteriér, Zjištěná poškození'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('vybrané fotky jdou smazat najednou', (tester) async {
    await otevriZakazku(tester);
    await klepni(
      tester,
      vKarte('exterier', find.byTooltip('Přidat z galerie')),
    );
    await klepni(
      tester,
      vKarte('poskozeni', find.byTooltip('Přidat z galerie')),
    );
    expect(zdroj.fotky['ZK-26-0001'], hasLength(4));

    // Dlouhý stisk zapne výběr, klepnutí přidává další fotky - i z jiné
    // kategorie.
    // Seznam kategorií je líný - po práci s druhou kartou je ta první
    // mimo paměť, tak se k ní vrátíme posunem nahoru.
    await tester.scrollUntilVisible(
      find.byKey(const Key('kategorie-exterier')),
      -300,
      scrollable: find
          .descendant(
            of: find.byType(FotodokumentaceObsah),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final prvni = vKarte('exterier', find.byType(Image)).first;
    await tester.longPress(prvni);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vyber-fotek')), findsOneWidget);
    expect(find.text('Vybráno: 1'), findsOneWidget);

    await klepni(tester, vKarte('poskozeni', find.byType(Image)).first);
    expect(find.text('Vybráno: 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('smazat-vybrane')));
    await tester.pumpAndSettle();
    // „Smazat" je i na tlačítku v liště - potvrzuje se to v dialogu,
    // který je v seznamu widgetů poslední.
    expect(find.text('Smazat 2 fotky?'), findsOneWidget);
    await tester.tap(find.text('Smazat').last);
    await tester.pumpAndSettle();

    expect(zdroj.fotky['ZK-26-0001'], hasLength(2));
    expect(find.byKey(const Key('vyber-fotek')), findsNothing);
  });

  testWidgets('karta v detailu hlásí fotky, které se nenahrály', (
    tester,
  ) async {
    await otevriZakazku(tester);
    zdroj.nahravaniSelze = true;
    await klepni(tester, vKarte('vin', find.byTooltip('Přidat z galerie')));
    await zpet(tester);

    final karta = await naKartuFotek(tester);
    expect(
      find.descendant(of: karta, matching: find.text('Nenahráno: 2')),
      findsOneWidget,
    );
  });

  testWidgets('fotky z galerie se nahrají do své kategorie', (tester) async {
    await otevriZakazku(tester);

    await klepni(
      tester,
      vKarte('exterier', find.byTooltip('Přidat z galerie')),
    );

    expect(vKarte('exterier', find.text('2 fotky')), findsOneWidget);
    expect(zdroj.fotky['ZK-26-0001'], hasLength(2));
    // Jiná kategorie zůstala prázdná.
    expect(vKarte('poskozeni', find.textContaining('fot')), findsNothing);
  });

  testWidgets('sériové focení nahraje každou fotku', (tester) async {
    await otevriZakazku(tester);

    await klepni(tester, vKarte('poskozeni', find.byTooltip('Vyfotit')));

    expect(vKarte('poskozeni', find.text('3 fotky')), findsOneWidget);
  });

  testWidgets('se zapnutou zálohou jde každá fotka i do telefonu', (
    tester,
  ) async {
    await otevriZakazku(
      tester,
      nastaveni: const Nastaveni(ukladatFotkyDoZarizeni: true),
    );

    await klepni(tester, vKarte('poskozeni', find.byTooltip('Vyfotit')));

    expect(ulozeni.ulozene, hasLength(3));
    expect(ulozeni.ulozene.first, startsWith('ZK-26-0001_poskozeni_'));
    // Záloha nahrávání nebrání.
    expect(zdroj.fotky['ZK-26-0001'], hasLength(3));
  });

  testWidgets('bez zálohy ani z galerie se do telefonu neukládá', (
    tester,
  ) async {
    await otevriZakazku(tester);
    await klepni(tester, vKarte('poskozeni', find.byTooltip('Vyfotit')));
    expect(ulozeni.ulozene, isEmpty);

    // Se zapnutou zálohou se neukládá ani z galerie - tam fotky už jsou.
    await tester.pumpWidget(const SizedBox());
    await otevriZakazku(
      tester,
      nastaveni: const Nastaveni(ukladatFotkyDoZarizeni: true),
    );
    await klepni(tester, vKarte('kola', find.byTooltip('Přidat z galerie')));
    expect(ulozeni.ulozene, isEmpty);
    expect(zdroj.fotky['ZK-26-0001'], hasLength(2));
  });

  testWidgets('nepovedenou zálohu aplikace ohlásí a fotku nahraje', (
    tester,
  ) async {
    await otevriZakazku(
      tester,
      nastaveni: const Nastaveni(ukladatFotkyDoZarizeni: true),
    );
    ulozeni.ulozeniSelze = true;

    await tester.ensureVisible(vKarte('vin', find.byTooltip('Vyfotit')));
    await tester.pumpAndSettle();
    await tester.tap(vKarte('vin', find.byTooltip('Vyfotit')));
    await tester.pump();

    expect(
      find.text('Fotku nejde uložit do telefonu - není v něm místo.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(zdroj.fotky['ZK-26-0001'], hasLength(3));
  });

  Future<void> naKartuNastaveni(WidgetTester tester, Finder cil) async {
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    // Karta je pod okrajem a seznam ji do té doby nepostaví.
    await tester.scrollUntilVisible(
      cil,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zálohu jde zapnout jen s přístupem k fotkám', (tester) async {
    await naZakazky(tester);
    final prepinac = find.byKey(const Key('ukladat-do-zarizeni'));
    await naKartuNastaveni(tester, prepinac);

    ulozeni.pristup = false;
    await tester.tap(prepinac);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(prepinac).value, isFalse);
    expect(find.textContaining('Bez přístupu k fotkám'), findsOneWidget);

    ulozeni.pristup = true;
    await tester.tap(prepinac);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(prepinac).value, isTrue);
  });

  testWidgets('fotka, která nešla nahrát, jde poslat znovu', (tester) async {
    await otevriZakazku(tester);
    zdroj.nahravaniSelze = true;

    await klepni(tester, vKarte('vin', find.byTooltip('Přidat z galerie')));
    expect(vKarte('vin', find.byKey(const Key('fotka-selhala'))), findsWidgets);

    zdroj.nahravaniSelze = false;
    await klepni(
      tester,
      vKarte('vin', find.byKey(const Key('fotka-selhala'))).first,
    );
    await tester.tap(find.text('Zkusit znovu'));
    await tester.pumpAndSettle();

    expect(zdroj.fotky['ZK-26-0001'], hasLength(1));
  });

  testWidgets('pobočka zvolená v nastavení jde s fotkou na server', (
    tester,
  ) async {
    await naZakazky(tester);
    final vyber = find.byKey(const Key('slozka-fotek'));
    await naKartuNastaveni(tester, vyber);
    expect(
      find.descendant(of: vyber, matching: find.text('Podle pořadače')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: vyber,
        matching: find.byType(DropdownButton<String?>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cestlice').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zakázky'));
    await tester.pumpAndSettle();
    await napis(tester, '2BK 9485');
    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();
    await klepni(tester, await naKartuFotek(tester));
    await klepni(tester, vKarte('vin', find.byTooltip('Přidat z galerie')));

    expect(zdroj.posledniPobocka, 'Cestlice');
  });

  group('příjem ze seznamu zakázek', () {
    testWidgets('nenalezenou zakázku jde dotáhnout z Heliosu a otevře se', (
      tester,
    ) async {
      await naZakazky(tester);
      zdroj.poSynchronizaci = [
        buildOrderDto(id: 'ZK-26-0003', licensePlate: '9Z9 1234'),
      ];
      await napis(tester, '9Z9 1234');

      expect(find.byType(OrderCard), findsNothing);
      await tester.tap(find.text('Načíst nové zakázky z Heliosu'));
      await tester.pumpAndSettle();

      expect(zdroj.pocetSynchronizaci, 1);
      // Kvůli ní se načítalo - otevře se rovnou.
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.text('ZK-26-0003'), findsWidgets);
    });

    testWidgets('bez hledaného textu se Helios nenabízí', (tester) async {
      await naZakazky(tester);
      await napis(tester, 'xx');
      expect(find.text('Načíst nové zakázky z Heliosu'), findsNothing);
    });

    testWidgets('po naskenování se jediná zakázka otevře rovnou', (
      tester,
    ) async {
      await naZakazky(tester);

      final kontejner = ProviderScope.containerOf(
        tester.element(find.byType(OrdersListScreen)),
      );
      // Tak to po naskenování dělá router.
      kontejner.read(otevritJedinouZakazkuProvider.notifier).state = true;
      kontejner.read(orderFilterProvider.notifier).setQuery('2BK 9485');
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailScreen), findsOneWidget);

      // Po návratu je naskenovaná SPZ v poli hledání a zakázka se znovu
      // sama neotvírá.
      await zpet(tester);
      expect(find.byType(OrderDetailScreen), findsNothing);
      final pole = tester.widget<TextField>(
        find.descendant(
          of: find.byType(OrdersListScreen),
          matching: find.byType(TextField),
        ),
      );
      expect(pole.controller!.text, '2BK 9485');
    });

    testWidgets('po naskenování víc zakázek zůstane seznam', (tester) async {
      await naZakazky(tester);

      final kontejner = ProviderScope.containerOf(
        tester.element(find.byType(OrdersListScreen)),
      );
      kontejner.read(otevritJedinouZakazkuProvider.notifier).state = true;
      // „ZK-26" mají obě zakázky.
      kontejner.read(orderFilterProvider.notifier).setQuery('ZK-26');
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailScreen), findsNothing);
      expect(find.byType(OrderCard), findsNWidgets(2));
    });
  });
}
