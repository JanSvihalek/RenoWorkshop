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
import 'package:renoworkshop/src/features/prijem/presentation/controllers/prijem_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/fotodokumentace_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/ulozeni_do_zarizeni.dart';
import 'package:renoworkshop/src/features/prijem/presentation/ziskani_fotek.dart';
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

  Future<void> naPrijem(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
  }) async {
    await tester.pumpWidget(buildApp(nastaveni: nastaveni));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Příjem'));
    await tester.pumpAndSettle();
  }

  Future<void> napis(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(PrijemScreen),
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

  Future<void> otevriZakazku(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
  }) async {
    await naPrijem(tester, nastaveni: nastaveni);
    await napis(tester, '2bk 94');
    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();
  }

  testWidgets('najde zakázku podle SPZ a otevře fotodokumentaci', (
    tester,
  ) async {
    await naPrijem(tester);
    expect(find.text('Najděte zakázku'), findsOneWidget);

    await napis(tester, '2bk 94');
    expect(find.byType(OrderCard), findsOneWidget);
    // Psaní rukou zakázku sama neotevírá.
    expect(find.byType(FotodokumentaceScreen), findsNothing);

    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();

    expect(find.byType(FotodokumentaceScreen), findsOneWidget);
    expect(find.text('Exteriér (dokola vozu)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ostatní dokumentace'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Ostatní dokumentace'), findsOneWidget);
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

  testWidgets('zálohu jde zapnout jen s přístupem k fotkám', (tester) async {
    await naPrijem(tester);
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();

    final prepinac = find.byKey(const Key('ukladat-do-zarizeni'));
    await tester.scrollUntilVisible(
      prepinac,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

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
    await naPrijem(tester);
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();

    final vyber = find.byKey(const Key('slozka-fotek'));
    // Karta je pod okrajem a seznam ji do té doby nepostaví.
    await tester.scrollUntilVisible(
      vyber,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Příjem'));
    await tester.pumpAndSettle();
    await napis(tester, '2bk 94');
    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();
    await klepni(tester, vKarte('vin', find.byTooltip('Přidat z galerie')));

    expect(zdroj.posledniPobocka, 'Cestlice');
  });

  testWidgets('nenalezenou zakázku jde dotáhnout z Heliosu', (tester) async {
    await naPrijem(tester);
    await napis(tester, '9Z9 1234');

    expect(find.text('Zakázka na dílně nenalezena'), findsOneWidget);
    await tester.tap(find.text('Načíst nové zakázky z Heliosu'));
    await tester.pumpAndSettle();

    expect(zdroj.pocetSynchronizaci, 1);
  });

  testWidgets('po naskenování se jediná zakázka otevře rovnou', (tester) async {
    await naPrijem(tester);

    final kontejner = ProviderScope.containerOf(
      tester.element(find.byType(PrijemScreen)),
    );
    kontejner.read(otevritJedinouZakazkuProvider.notifier).state = true;
    kontejner.read(dotazPrijmuProvider.notifier).state = '2BK 9485';
    await tester.pumpAndSettle();

    expect(find.byType(FotodokumentaceScreen), findsOneWidget);
  });
}
