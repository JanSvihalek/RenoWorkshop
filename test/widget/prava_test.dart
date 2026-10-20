import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/moje_prava.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Práva k pořadačům: jen čtení schová akce, které zapisují, a uživatel
/// bez práv dostane hlášku místo prázdného seznamu.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  const bsl = {'code': '10026', 'label': 'BMW BSL'};

  Future<void> spust(
    WidgetTester tester, {
    required List<ServiceOrderDto> zakazky,
    required MojePrava prava,
  }) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zdroj = FakeServiceOrderDataSource(zakazky)..prava = prava;
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
  }

  test('pravidla: W zápis, R jen čtení, admin vše', () {
    const user = MojePrava(
      role: 'user',
      poradace: {'10026': 'W', '16015': 'R'},
    );
    expect(user.smiZapisovat('10026'), isTrue);
    expect(user.smiZapisovat('16015'), isFalse);
    expect(user.smiZapisovat(null), isFalse);
    expect(MojePrava.vse.smiZapisovat(null), isTrue);
    expect(const MojePrava(role: 'user', poradace: {}).bezPristupu, isTrue);
    expect(
      MojePrava.fromJson({
        'role': 'user',
        'folders': [
          {'code': '10026', 'access': 'R'},
        ],
      }).poradace,
      {'10026': 'R'},
    );
  });

  test('plánovač: výchozí prohlížet, plánovat jen se zápisem', () {
    const prohlizi = MojePrava(role: 'user', poradace: {'10026': 'W'});
    expect(prohlizi.smiPlanovat('10026'), isFalse);
    expect(prohlizi.vidiPlanovac, isTrue);
    const planuje = MojePrava(
      role: 'user',
      poradace: {'10026': 'W', '16015': 'R'},
      planovac: 'planovat',
    );
    expect(planuje.smiPlanovat('10026'), isTrue);
    expect(planuje.smiPlanovat('16015'), isFalse);
    expect(MojePrava.vse.smiPlanovat(null), isTrue);
    expect(
      const MojePrava(
        role: 'user',
        poradace: {},
        planovac: 'zadne',
      ).vidiPlanovac,
      isFalse,
    );
    expect(MojePrava.fromJson({'role': 'user'}).planovac, 'cist');
    expect(
      MojePrava.fromJson({'role': 'user', 'planner': 'edit'}).planovac,
      'planovat',
    );
    expect(planovacDoApi('zadne'), 'none');
  });

  testWidgets('jen čtení: štítek a bez akcí, které zapisují', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(utvar: '11215', canPlanBodyshop: true, folder: bsl),
      ],
      prava: const MojePrava(role: 'user', poradace: {'10026': 'R'}),
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jen-cteni')), findsOneWidget);
    expect(find.byKey(const Key('pridat-stav')), findsNothing);
    expect(find.byKey(const Key('zaplanovat-klempirnu')), findsNothing);
    expect(find.text('Převzít'), findsNothing);
  });

  testWidgets('zápis bez plánovače: stav ano, plánovat ne', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(utvar: '11215', canPlanBodyshop: true, folder: bsl),
      ],
      prava: const MojePrava(role: 'user', poradace: {'10026': 'W'}),
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pridat-stav')), findsOneWidget);
    expect(find.byKey(const Key('zaplanovat-klempirnu')), findsNothing);
    expect(find.byKey(const Key('otevrit-planovac')), findsOneWidget);
  });

  testWidgets('plánovač nevidí: bez dlaždice i odkazu', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(utvar: '11215', canPlanBodyshop: true, folder: bsl),
      ],
      prava: const MojePrava(
        role: 'user',
        poradace: {'10026': 'W'},
        planovac: 'zadne',
      ),
    );
    final nav = find.byKey(const Key('nav-aplikace'));
    await tester.tap(
      nav.evaluate().isNotEmpty
          ? nav
          : find.byKey(const Key('prepinac-aplikaci')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-aplikaci')), findsOneWidget);
    expect(find.byKey(const Key('aplikace-plan')), findsNothing);
    await tester.tapAt(const Offset(1200, 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otevrit-planovac')), findsNothing);
  });

  testWidgets('zápis s plánovačem: akce jsou', (tester) async {
    await spust(
      tester,
      zakazky: [
        buildOrderDto(utvar: '11215', canPlanBodyshop: true, folder: bsl),
      ],
      prava: const MojePrava(
        role: 'user',
        poradace: {'10026': 'W'},
        planovac: 'planovat',
      ),
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jen-cteni')), findsNothing);
    expect(find.byKey(const Key('pridat-stav')), findsOneWidget);
    expect(find.byKey(const Key('zaplanovat-klempirnu')), findsOneWidget);
  });

  testWidgets('bez práv: hláška místo prázdného seznamu', (tester) async {
    await spust(
      tester,
      zakazky: const [],
      prava: const MojePrava(role: 'user', poradace: {}),
    );
    expect(find.byKey(const Key('bez-pristupu')), findsOneWidget);
  });
}
