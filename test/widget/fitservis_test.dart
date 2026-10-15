import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/domain/kampan_podle_stari.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/kampan_vozidla.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// FitServis+ a další kampaně podle stáří vozu: štítek v detailu zakázky,
/// správa v Nastavení jen pro správce.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  const fitservis = KampanPodleStari(
    id: 'fitservis-plus',
    nazev: 'FitServis+',
    text: 'Kampaň BMW pro vozy starší 48 měsíců.',
    odMesicu: 48,
  );

  Future<void> spust(
    WidgetTester tester, {
    bool spravce = false,
    List<KampanVozidla> kampaneVozu = const [],
  }) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    zdroj =
        FakeServiceOrderDataSource([
            buildOrderDto(
              firstRegisteredAt: '2019-05-03',
              ageCampaigns: kampaneVozu,
            ),
          ])
          ..kampaneStari = [fitservis]
          ..spravceKampaniStari = spravce;
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
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  test('zakázka nese první registraci a kampaně podle stáří', () {
    final z = ServiceOrderDto.fromJson({
      'id': 'Z1',
      'licensePlate': '1AA 1111',
      'model': 'BMW 320d',
      'customerName': 'Petr Novák',
      'vin': 'WBA3A5C51DF123456',
      'mechanicName': null,
      'firstRegisteredAt': '2019-05-03',
      'ageCampaigns': [
        {'id': 'fitservis-plus', 'title': 'FitServis+', 'text': ''},
      ],
    }).toDomain();
    expect(z.prvniRegistrace, DateTime(2019, 5, 3));
    expect(z.kampanePodleStari.single.nazev, 'FitServis+');
  });

  test('kampaň podle stáří ze serveru a zpět', () {
    final k = KampanPodleStari.fromJson({
      'id': 'k',
      'title': 'Starší vozy',
      'text': '',
      'fromMonths': 48,
      'toMonths': 96,
      'active': false,
    });
    expect(k.rozsah, 'Vozy od 48 do 96 měsíců');
    expect(fitservis.rozsah, 'Vozy od 48 měsíců');
    expect(k.toJson(), {
      'title': 'Starší vozy',
      'text': '',
      'fromMonths': 48,
      'toMonths': 96,
      'active': false,
    });
  });

  testWidgets('vůz ve FitServis+ má v detailu modrý štítek s registrací', (
    tester,
  ) async {
    await spust(
      tester,
      kampaneVozu: const [
        KampanVozidla(
          id: 'fitservis-plus',
          nazev: 'FitServis+',
          text: 'Kampaň BMW pro vozy starší 48 měsíců.',
        ),
      ],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    final stitek = find.byKey(const Key('kampan-stari-fitservis-plus'));
    expect(stitek, findsOneWidget);
    await tester.tap(stitek);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Kampaň BMW pro vozy starší 48 měsíců.\n\n'
        'První registrace: 3. 5. 2019',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mladší vůz štítek nemá', (tester) async {
    await spust(tester);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kampan-stari-fitservis-plus')), findsNothing);
  });

  testWidgets('kdo není správce, skupinu v Nastavení nevidí', (tester) async {
    await spust(tester);
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    expect(find.text('KAMPANĚ PODLE STÁŘÍ VOZU'), findsNothing);
  });

  testWidgets('správce v Nastavení změní stáří a kampaň vypne', (tester) async {
    await spust(tester, spravce: true);
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    expect(find.text('KAMPANĚ PODLE STÁŘÍ VOZU'), findsOneWidget);
    expect(find.text('Vozy od 48 měsíců'), findsOneWidget);

    await tester.tap(find.byKey(const Key('kampan-stari-fitservis-plus')));
    await tester.pumpAndSettle();
    final ulozit = find.byKey(const Key('kampan-stari-ulozit'));
    bool lze() => tester.widget<FilledButton>(ulozit).onPressed != null;

    await tester.enterText(find.byKey(const Key('kampan-stari-do')), '40');
    await tester.pump();
    expect(lze(), isFalse, reason: '„do" pod „od" nedává smysl');

    await tester.enterText(find.byKey(const Key('kampan-stari-od')), '60');
    await tester.enterText(find.byKey(const Key('kampan-stari-do')), '');
    await tester.tap(find.byKey(const Key('kampan-stari-aktivni')));
    await tester.pump();
    expect(lze(), isTrue);

    await tester.tap(ulozit);
    await tester.pumpAndSettle();

    final ulozena = zdroj.kampaneStari.single;
    expect(ulozena.odMesicu, 60);
    expect(ulozena.doMesicu, isNull);
    expect(ulozena.aktivni, isFalse);
    expect(find.text('Vozy od 60 měsíců · vypnutá'), findsOneWidget);
  });
}
