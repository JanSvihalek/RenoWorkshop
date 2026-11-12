import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/data/dtos/service_order_dto.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/dilensky_stav.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/zavada.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Hlavička detailu (IČO, schování zákazníka, zadání zpracovatele)
/// a Zahájit/Dokončit u závad - zapisují se do průběhu opravy.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  const zavada = Zavada(id: '77', nazev: 'Výměna oleje', text: '');

  Future<FakeServiceOrderDataSource> otevri(
    WidgetTester tester,
    ServiceOrderDto zakazka,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final zdroj = FakeServiceOrderDataSource([zakazka]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serviceOrderDataSourceProvider.overrideWithValue(zdroj)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrderDetailScreen(orderId: zakazka.id, onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return zdroj;
  }

  group('stav závady', () {
    DilenskyStav zaznam(String id, String? zavadaId, {DateTime? dokonceno}) =>
        DilenskyStav(
          id: id,
          nazev: 'x',
          zavadaId: zavadaId,
          dokonceno: dokonceno,
        );

    test('čeká, probíhá, dokončená; přerušenou jde zahájit znovu', () {
      expect(stavZavady('1', const []), isA<ZavadaCeka>());
      expect(stavZavady('1', [zaznam('a', '1')]), isA<ZavadaProbiha>());
      expect(
        stavZavady('1', [zaznam('a', '1', dokonceno: DateTime(2026, 11, 3))]),
        isA<ZavadaHotova>(),
      );
      expect(
        stavZavady('1', [zaznam('b', '2'), zaznam('a', '1')]),
        isA<ZavadaCeka>(),
      );
    });

    test('název kroku: popis, jinak první řádek poznámky, nejvýš 100', () {
      expect(zavada.nazevKroku, 'Výměna oleje');
      expect(const Zavada(id: '1', text: 'Olej\nvýměna').nazevKroku, 'Olej');
      expect(const Zavada(id: '1', text: '').nazevKroku, 'Závada');
      expect(
        Zavada(id: '1', nazev: 'a' * 150, text: '').nazevKroku,
        hasLength(100),
      );
    });
  });

  testWidgets('závadu jde zahájit a dokončit, krok je v průběhu', (
    tester,
  ) async {
    final zdroj = await otevri(tester, buildOrderDto(defects: const [zavada]));

    final zahajit = find.byKey(const Key('zavada-zahajit-77'));
    await tester.ensureVisible(zahajit);
    await tester.pumpAndSettle();
    await tester.tap(zahajit);
    await tester.pumpAndSettle();

    expect(find.text('Zahájit: Výměna oleje'), findsOneWidget);
    expect(find.text('STAV'), findsNothing, reason: 'stav se nevybírá');
    await tester.tap(find.widgetWithText(FilledButton, 'Zahájit'));
    await tester.pumpAndSettle();

    final ulozena = zdroj.ulozeneDto('ZK-26-0001');
    expect(ulozena.statusHistory.first['defectId'], '77');
    expect(ulozena.statusHistory.first['label'], 'Výměna oleje');
    expect(find.byKey(const Key('zavada-probiha-77')), findsOneWidget);
    expect(zahajit, findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('osa-prubehu')),
        matching: find.textContaining('Výměna oleje'),
      ),
      findsWidgets,
    );

    final dokoncit = find.byKey(const Key('zavada-dokoncit-77'));
    await tester.ensureVisible(dokoncit);
    await tester.pumpAndSettle();
    await tester.tap(dokoncit);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('zavada-hotovo-77')), findsOneWidget);
    // Hotový úkon má zelenou fajfku.
    expect(find.byKey(const Key('zavada-fajfka-77')), findsOneWidget);
    expect(zahajit, findsNothing);
  });

  testWidgets('ostatní přání pod závadami: vždy všechna, i Ne a Nezadáno', (
    tester,
  ) async {
    await otevri(
      tester,
      buildOrderDto(
        defects: const [zavada],
        customerWishes: const {
          'wash': true,
          'washProgram': 'P3',
          'returnParts': false,
          'operatingFluids': null,
        },
      ),
    );
    expect(find.text('OSTATNÍ PŘÁNÍ'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('prani-zakaznika'))).dy,
      greaterThan(tester.getTopLeft(find.text('Výměna oleje').first).dy),
    );
    expect(find.text('Mytí: Ano · P3'), findsOneWidget);
    expect(find.text('Vrátit vyměněné díly: Ne'), findsOneWidget);
    expect(find.text('Provozní kapaliny: Nezadáno'), findsOneWidget);
  });

  testWidgets('nevyplněná přání jsou Nezadáno', (tester) async {
    await otevri(tester, buildOrderDto());
    expect(find.textContaining(': Nezadáno'), findsNWidgets(3));
  });

  testWidgets(
    'ruční úkon: přidávání schované, Zahájit s vazbou na úkon a smazání',
    (tester) async {
      final zdroj = await otevri(
        tester,
        buildOrderDto(
          defects: const [zavada],
          manualTasks: [
            RucniUkon(
              id: 'ukon-1',
              nazev: 'Výměna stírátek',
              pridal: 'Test Technik',
              pridano: DateTime(2026, 11, 8, 8, 50),
            ),
          ],
        ),
      );
      expect(find.text('HELIOS'), findsOneWidget);
      // Závady a úkony se zadávají jen v Heliosu (12. 11. 2026).
      expect(find.byKey(const Key('pridat-ukon')), findsNothing);

      expect(find.text('Výměna stírátek'), findsWidgets);
      expect(find.text('RUČNĚ · MIMO HELIOS'), findsOneWidget);
      expect(find.text('· 1 z Heliosu · 1 ručně mimo Helios'), findsOneWidget);
      expect(find.textContaining('přidal Test Technik'), findsOneWidget);

      final zahajit = find.byKey(const Key('ukon-zahajit-ukon-1'));
      await tester.ensureVisible(zahajit);
      await tester.pumpAndSettle();
      await tester.tap(zahajit);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Zahájit'));
      await tester.pumpAndSettle();
      final ulozena = zdroj.ulozeneDto('ZK-26-0001');
      expect(ulozena.statusHistory.first['taskId'], 'ukon-1');
      expect(ulozena.statusHistory.first['defectId'], isNull);
      expect(find.byKey(const Key('ukon-probiha-ukon-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ukon-menu-ukon-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smazat úkon'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ukon-smazat-potvrdit')));
      await tester.pumpAndSettle();
      expect(find.text('RUČNĚ · MIMO HELIOS'), findsNothing);
      expect(zdroj.ulozeneDto('ZK-26-0001').manualTasks, isEmpty);
    },
  );

  test('přerušený ruční úkon jde zahájit znovu', () {
    const historie = [
      DilenskyStav(id: 'b', nazev: 'jiný krok'),
      DilenskyStav(id: 'a', nazev: 'x', ukonId: 'u1'),
    ];
    final stav = stavZavady('u1', historie, rucni: true);
    expect(stav, isA<ZavadaCeka>());
    expect((stav as ZavadaCeka).preruseno, isTrue);
    expect(stavZavady('u1', historie), isA<ZavadaCeka>());
    expect((stavZavady('u1', historie) as ZavadaCeka).preruseno, isFalse);
  });

  testWidgets('hlavička: IČO, schování celého pruhu a Zadat u zpracovatele', (
    tester,
  ) async {
    await otevri(tester, buildOrderDto(customerIco: '12345678'));

    expect(find.text('IČO 12345678'), findsOneWidget);
    expect(find.text('ZÁKAZNÍK'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('zpracovatel-zmenit')),
              matching: find.byType(Text),
            ),
          )
          .data,
      'Zadat',
    );

    await tester.tap(find.byKey(const Key('skryt-udaje')));
    await tester.pumpAndSettle();
    expect(find.text('ZÁKAZNÍK'), findsNothing);
    expect(find.byKey(const Key('kontakt')), findsNothing);
    expect(find.text('ZPRACOVÁVÁ'), findsNothing);

    await tester.tap(find.byKey(const Key('skryt-udaje')));
    await tester.pumpAndSettle();
    expect(find.text('ZÁKAZNÍK'), findsOneWidget);
  });
}
