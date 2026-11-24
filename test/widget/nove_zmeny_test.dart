import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/nova_zmena.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Zpětné tlačítko detailu - ikona se liší podle platformy.
Finder _zpet() => find.byWidgetPredicate(
  (widget) =>
      widget is Icon &&
      (widget.icon == Icons.arrow_back_rounded ||
          widget.icon == Icons.arrow_back_ios_new_rounded),
);

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  group('nová změna ze služby', () {
    test('text podle druhu, kdo a kdy', () {
      final zmena = NovaZmena.zJson({
        'kind': 'finished',
        'label': 'Demontáž',
        'by': 'Eva Malá',
        'at': '2026-11-24T10:05:00',
        'count': 3,
      })!;
      expect(zmena.text, 'Dokončeno: Demontáž');
      expect(zmena.pocet, 3);
      expect(zmena.kdoKdy(DateTime(2026, 11, 24, 15)), 'Eva Malá · 10:05');
      expect(zmena.kdoKdy(DateTime(2026, 11, 25)), 'Eva Malá · 24. 11. 10:05');
      expect(
        zmena.kdoKdy(DateTime(2027, 1, 2)),
        'Eva Malá · 24. 11. 2026 10:05',
      );
    });

    test('neznámý druh nebo pokažené datum - bez štítku', () {
      expect(NovaZmena.zJson(null), isNull);
      expect(
        NovaZmena.zJson({'kind': 'jiny', 'at': '2026-11-24T10:05:00'}),
        isNull,
      );
      expect(NovaZmena.zJson({'kind': 'note', 'at': 'nic'}), isNull);
    });
  });

  late FakeServiceOrderDataSource zdroj;

  Widget buildApp() {
    zdroj = FakeServiceOrderDataSource([
      buildOrderDto(
        id: 'ZK-26-0001',
        licensePlate: '8AB 4721',
        unseenChange: {
          'kind': 'status',
          'label': 'Lakovna',
          'by': 'Eva Malá',
          'at': '2026-11-24T10:05:00',
          'count': 2,
        },
      ),
      buildOrderDto(id: 'ZK-26-0002', licensePlate: '2SC 9014'),
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
      ],
      child: const RenoWorkshopApp(),
    );
  }

  Future<void> prihlas(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  testWidgets('štítek na kartě, číslo v navigaci, přepínač a označit vše', (
    tester,
  ) async {
    await prihlas(tester);

    expect(find.byKey(const Key('karta-nova-zmena')), findsOneWidget);
    expect(find.text('Nový stav: Lakovna'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.byKey(const Key('nav-pocet-zmen')), findsOneWidget);

    // Jen změněné - druhá zakázka zmizí.
    await tester.tap(find.byKey(const Key('nove-zmeny-prepinac')));
    await tester.pumpAndSettle();
    expect(find.text('2SC 9014'), findsNothing);
    expect(find.text('8AB 4721'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nove-zmeny-oznacit-vse')));
    await tester.pumpAndSettle();
    expect(zdroj.videne, ['ZK-26-0001']);
    expect(find.byKey(const Key('karta-nova-zmena')), findsNothing);
    expect(find.byKey(const Key('nav-pocet-zmen')), findsNothing);
    // Bez nových změn se přepínač vypne - seznam je zase celý.
    expect(find.byKey(const Key('nove-zmeny-prepinac')), findsNothing);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('otevření detailu zakázku označí jako viděnou', (tester) async {
    await prihlas(tester);

    await tester.tap(find.text('8AB 4721'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-nova-zmena')), findsOneWidget);
    expect(find.textContaining('Od vaší poslední návštěvy'), findsOneWidget);
    expect(zdroj.videne, ['ZK-26-0001']);

    // Pruh zůstane, dokud ho křížkem neschová.
    await tester.tap(find.byKey(const Key('detail-nova-zmena-skryt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-nova-zmena')), findsNothing);

    await tester.tap(_zpet().first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('karta-nova-zmena')), findsNothing);
    expect(find.byKey(const Key('nav-pocet-zmen')), findsNothing);
  });
}
