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
    expect(zahajit, findsNothing);
  });

  testWidgets('ostatní přání pod závadami: Ano s programem, Ne, Nezadáno', (
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
    expect(find.text('Ostatní přání'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('prani-zakaznika'))).dy,
      greaterThan(tester.getTopLeft(find.text('Výměna oleje').first).dy),
    );
    expect(find.text('Ano · P3'), findsOneWidget);
    expect(find.text('Ne'), findsOneWidget);
    expect(find.text('Nezadáno'), findsOneWidget);
  });

  testWidgets('bez přání zákazníka se pruh neukáže', (tester) async {
    await otevri(tester, buildOrderDto());
    expect(find.byKey(const Key('prani-zakaznika')), findsNothing);
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
