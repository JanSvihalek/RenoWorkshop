import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/nova_zmena.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/widgets/nova_zmena.dart';

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
        // Jediný záznam historie je ten, který změnu udělal - předtím
        // zakázka stav neměla.
        status: 'Lakovna',
        statusCode: 'lakovna',
        unseenChange: {
          'kind': 'status',
          'label': 'Lakovna',
          'by': 'Eva Malá',
          'at': '2026-08-20T09:00:00',
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

  /// Text tooltipu změny (richMessage) - pro kontrolu obsahu.
  Iterable<String> tooltipy(WidgetTester tester) => tester
      .widgetList<Tooltip>(find.byType(Tooltip))
      .map((t) => t.richMessage?.toPlainText() ?? t.message ?? '');

  testWidgets('karta: proužek, tečka, kroužek se starým → novým stavem', (
    tester,
  ) async {
    await prihlas(tester);

    expect(find.byKey(const Key('karta-zmena-prouzek')), findsOneWidget);
    expect(find.byKey(const Key('stav-se-zmenou')), findsOneWidget);
    expect(find.byType(TeckaZmeny), findsWidgets);
    expect(
      tooltipy(tester),
      // Datum bez roku jen letos - konec se kontroluje bez data.
      contains(
        allOf(
          startsWith('ZMĚNA · STAV DÍLNA\nBez stavu → Lakovna\n'),
          endsWith('9:00 · Eva Malá · +1 další'),
        ),
      ),
    );
    expect(
      find.text('1 zakázka se změnila od vašeho posledního zobrazení'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nav-pocet-zmen')), findsOneWidget);
  });

  testWidgets('lišta: jen změněné, podruhé vypne, označit vše', (tester) async {
    await prihlas(tester);

    final jenZmenene = find.byKey(const Key('lista-zmen-jen-zmenene'));
    await tester.tap(jenZmenene);
    await tester.pumpAndSettle();
    expect(find.text('2SC 9014'), findsNothing);
    expect(find.text('8AB 4721'), findsOneWidget);
    await tester.tap(jenZmenene);
    await tester.pumpAndSettle();
    expect(find.text('2SC 9014'), findsOneWidget);

    await tester.tap(jenZmenene);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lista-zmen-oznacit-vse')));
    await tester.pumpAndSettle();
    expect(zdroj.videne, ['ZK-26-0001']);
    expect(find.byKey(const Key('karta-zmena-prouzek')), findsNothing);
    expect(find.byKey(const Key('nav-pocet-zmen')), findsNothing);
    // Bez změněných se lišta schová a filtr vypne - seznam je zase celý.
    expect(find.byKey(const Key('lista-zmen')), findsNothing);
    expect(find.text('2SC 9014'), findsOneWidget);
  });

  testWidgets('tečka pulzuje jen třikrát, při vypnutých animacích vůbec', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: TeckaZmeny())),
      ),
    );
    // Tři cykly a pak klid - pumpAndSettle by s nekonečnou animací
    // nedoběhl.
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(child: TeckaZmeny(key: Key('bez'))),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('skloňování lišty', () {
    expect(
      textListyZmen(1),
      '1 zakázka se změnila od vašeho posledního zobrazení',
    );
    expect(
      textListyZmen(3),
      '3 zakázky se změnily od vašeho posledního zobrazení',
    );
    expect(
      textListyZmen(5),
      '5 zakázek se změnilo od vašeho posledního zobrazení',
    );
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
    expect(find.byKey(const Key('karta-zmena-prouzek')), findsNothing);
    expect(find.byKey(const Key('nav-pocet-zmen')), findsNothing);
  });
}
