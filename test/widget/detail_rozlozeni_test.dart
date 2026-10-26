import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';
import '../helpers/zalozky.dart';

/// Detail: vlevo menu sekcí, uprostřed sekce, vpravo průběh (postup,
/// poznámky). Užší displej má průběh pod sekcí, telefon menu nahoře.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<void> otevri(WidgetTester tester, Size velikost) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(
            FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrderDetailScreen(
            orderId: 'ZK-26-0001',
            onBack: () {},
            onFotodokumentace: (_) {},
            onPrijem: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final fotkyKarta = find.byKey(const Key('otevrit-fotodokumentaci'));
  final postupKarta = find.byKey(const Key('pridat-stav'));

  testWidgets('sekce Závady, Příjem, Dokumenty, Uloženky - otevírá se Závady', (
    tester,
  ) async {
    await otevri(tester, const Size(800, 1400));

    // Závady a s nimi průběh (postup, poznámky) - patří k sobě.
    expect(find.text('ZÁVADY/ÚKONY'), findsOneWidget);
    expect(postupKarta, findsOneWidget);
    expect(find.byKey(const Key('otevrit-prijem')), findsNothing);
    expect(fotkyKarta, findsNothing);

    // Ostatní sekce už průběh nemají.
    await naSekci(tester, 'prijem');
    expect(find.byKey(const Key('otevrit-prijem')), findsOneWidget);
    expect(postupKarta, findsNothing);

    await naSekci(tester, 'dokumenty');
    expect(fotkyKarta, findsOneWidget);
    expect(find.byKey(const Key('diagnostika-karta')), findsOneWidget);
    expect(find.byKey(const Key('dokumenty-heliosu')), findsOneWidget);

    await naSekci(tester, 'ulozenky');
    expect(find.byKey(const Key('ulozenky-pneu')), findsOneWidget);
  });

  testWidgets(
    'na širokém tabletu jsou v závadách postup vedle, jinde celá šířka',
    (tester) async {
      await otevri(tester, const Size(1280, 1400));

      final menu = tester.getRect(find.byKey(const Key('sekce-zavady')));
      final zavady = tester.getRect(find.byKey(const Key('zavady-karta')));
      final postup = tester.getRect(postupKarta);
      expect(menu.right, lessThanOrEqualTo(zavady.left));
      expect(zavady.right, lessThanOrEqualTo(postup.left));

      // Dokumenty přes celou šířku vedle menu.
      await naSekci(tester, 'dokumenty');
      expect(
        tester.getRect(find.byKey(const Key('dokumenty-karta'))).width,
        greaterThan(900),
      );
    },
  );

  testWidgets('na telefonu je menu nahoře a karty pod sebou', (tester) async {
    await otevri(tester, const Size(500, 1400));

    final menu = tester.getRect(find.byKey(const Key('sekce-zavady')));
    final zavady = tester.getRect(find.byKey(const Key('zavady-karta')));
    final postup = tester.getRect(postupKarta);
    expect(menu.bottom, lessThanOrEqualTo(zavady.top));
    expect(zavady.top, lessThan(postup.top));
    expect(zavady.width, greaterThan(450));
  });

  final udaje = find.byKey(const Key('hlavicka-udaje'));

  testWidgets('na tabletu jsou termíny v hlavičce vpravo vedle vozu', (
    tester,
  ) async {
    await otevri(tester, const Size(1280, 800));

    final spz = tester.getRect(find.text('1AA 1111'));
    final rect = tester.getRect(udaje);
    expect(rect.left, greaterThan(640));
    expect(rect.top, lessThan(spz.bottom));
    expect(
      find.descendant(of: udaje, matching: find.text('TERMÍN DOKONČENÍ')),
      findsOneWidget,
    );
    // Karty s termíny v těle detailu už nejsou.
    expect(find.text('PŘIJATO'), findsOneWidget);
  });

  testWidgets('na telefonu jsou termíny v hlavičce pod vozem', (tester) async {
    await otevri(tester, const Size(600, 1400));

    final spz = tester.getRect(find.text('1AA 1111'));
    final rect = tester.getRect(udaje);
    expect(rect.top, greaterThan(spz.bottom));
    expect(rect.left, lessThan(100));
  });
}
