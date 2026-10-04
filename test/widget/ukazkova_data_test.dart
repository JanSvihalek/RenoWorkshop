import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/stav_serveru.dart';
import 'package:renoworkshop/src/features/orders/data/datasources/mock_service_order_data_source.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/repositories/service_order_repository.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Server mimo firemní síť neodpovídá.
class _MimoFirmu extends FakeServiceOrderDataSource {
  _MimoFirmu() : super(const []);

  @override
  Future<List<ServiceOrderDto>> fetchOrders() async =>
      throw const ServiceOrderException('Server neodpovídá.');
}

/// Mimo firmu se technik na server nedostane. Ukázková data se proto dají
/// zapnout i v buildu se službou - z nastavení nebo z chyby seznamu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  group('zdroj dat', () {
    ProviderContainer kontejner({
      required bool seSluzbou,
      required bool ukazkovaData,
    }) {
      final c = ProviderContainer(
        overrides: [
          buildSeSluzbouProvider.overrideWithValue(seSluzbou),
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(Nastaveni(ukazkovaData: ukazkovaData)),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('zapnutá ukázková data vymění službu za mock', () {
      final c = kontejner(seSluzbou: true, ukazkovaData: true);

      expect(c.read(pouzivaApiProvider), isFalse);
      expect(
        c.read(serviceOrderDataSourceProvider),
        isA<MockServiceOrderDataSource>(),
      );
    });

    test('vypnutím se appka vrátí ke službě', () {
      final c = kontejner(seSluzbou: true, ukazkovaData: true);
      expect(c.read(pouzivaApiProvider), isFalse);

      c.read(nastaveniProvider.notifier).zmenUkazkovaData(false);

      expect(c.read(pouzivaApiProvider), isTrue);
    });

    test('build bez služby jede na ukázce vždycky', () {
      final c = kontejner(seSluzbou: false, ukazkovaData: false);

      expect(c.read(pouzivaApiProvider), isFalse);
    });
  });

  test('ukázková data mají závady i zakázkový list z Heliosu', () async {
    final zdroj = MockServiceOrderDataSource(latency: Duration.zero);
    final zakazky = await zdroj.fetchOrders();

    // Bez závad by v detailu nebylo vidět, jak karta vypadá.
    expect(zakazky.where((z) => z.defects.isNotEmpty).length, greaterThan(3));

    final dokumenty = await zdroj.dokumentyHeliosu(zakazky.first.id);
    expect(dokumenty, hasLength(1));
    expect(dokumenty.single.zHeliosu, isTrue);

    final pdf = await zdroj.stahniDokument(
      zakazky.first.id,
      dokumenty.single.id,
    );
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  late PametoveNastaveni uloziste;

  Future<void> spust(
    WidgetTester tester,
    FakeServiceOrderDataSource zdroj,
  ) async {
    uloziste = PametoveNastaveni();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            PlaceholderAuthRepository(
              ssoDelay: Duration.zero,
              biometricDelay: Duration.zero,
            ),
          ),
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          nastaveniUlozisteProvider.overrideWithValue(uloziste),
          buildSeSluzbouProvider.overrideWithValue(true),
          verzeAplikaceProvider.overrideWith((ref) async => '1.2.0 (80)'),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  final pruh = find.byKey(const Key('ukazkova-data-pruh'));

  testWidgets('přepínač v nastavení zapne ukázková data a ukáže pruh', (
    tester,
  ) async {
    await spust(tester, FakeServiceOrderDataSource([buildOrderDto()]));
    expect(pruh, findsNothing);

    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    final prepinac = find.byKey(const Key('ukazkova-data'));
    await tester.scrollUntilVisible(
      prepinac,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(prepinac);
    await tester.pumpAndSettle();

    expect(uloziste.nacti().ukazkovaData, isTrue);
    expect(pruh, findsOneWidget);
    // Zdroj dat i stav serveru říkají totéž.
    expect(find.text('Ukázková data'), findsNWidgets(3));

    await tester.tap(find.byKey(const Key('vypnout-ukazkova-data')));
    await tester.pumpAndSettle();

    expect(uloziste.nacti().ukazkovaData, isFalse);
    expect(pruh, findsNothing);
    expect(find.text('Helios Data'), findsOneWidget);
  });

  testWidgets('nenačtený seznam nabídne ukázková data', (tester) async {
    await spust(tester, _MimoFirmu());

    expect(find.text('Zakázky se nepodařilo načíst'), findsOneWidget);
    await tester.tap(find.byKey(const Key('zapnout-ukazkova-data')));
    await tester.pumpAndSettle();

    expect(uloziste.nacti().ukazkovaData, isTrue);
    expect(pruh, findsOneWidget);
    // Se zapnutou ukázkou už není co nabízet.
    expect(find.byKey(const Key('zapnout-ukazkova-data')), findsNothing);
  });
}
