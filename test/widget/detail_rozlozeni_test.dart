import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';
import '../helpers/zalozky.dart';

/// Detail má záložky Práce · Vůz · Dokumenty. Na širokém tabletu má obsah
/// záložky dva sloupce, na telefonu i v rozděleném zobrazení jeden.
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

  testWidgets('záložky Práce, Vůz, Dokumenty - otevírá se Práce', (
    tester,
  ) async {
    await otevri(tester, const Size(800, 1400));

    // Práce: závady, postup, poznámky. Příjem a fotky jsou jinde.
    expect(find.text('ZÁVADY/ÚKONY'), findsOneWidget);
    expect(postupKarta, findsOneWidget);
    expect(find.byKey(const Key('otevrit-prijem')), findsNothing);
    expect(fotkyKarta, findsNothing);

    await naZalozku(tester, 'vuz');
    expect(find.byKey(const Key('otevrit-prijem')), findsOneWidget);
    expect(find.byKey(const Key('diagnostika-karta')), findsOneWidget);
    expect(find.byKey(const Key('ulozenky-pneu')), findsOneWidget);
    expect(postupKarta, findsNothing);

    await naZalozku(tester, 'dokumenty');
    expect(fotkyKarta, findsOneWidget);
    expect(find.byKey(const Key('dokumenty-heliosu')), findsOneWidget);
  });

  testWidgets('na širokém tabletu je postup vpravo od závad', (tester) async {
    await otevri(tester, const Size(1280, 1400));

    final zavady = tester.getRect(find.text('ZÁVADY/ÚKONY'));
    final postup = tester.getRect(postupKarta);
    // Každá karta je ve své polovině obrazovky.
    expect(zavady.right, lessThan(640));
    expect(postup.left, greaterThan(640));

    // Dokumenty: fotky vlevo, dokumenty Helios vpravo.
    await naZalozku(tester, 'dokumenty');
    expect(tester.getRect(fotkyKarta).right, lessThan(640));
    expect(
      tester.getRect(find.byKey(const Key('dokumenty-heliosu'))).left,
      greaterThan(640),
    );
  });

  testWidgets('na telefonu jsou karty záložky pod sebou', (tester) async {
    await otevri(tester, const Size(800, 1400));

    final zavady = tester.getRect(find.text('ZÁVADY/ÚKONY'));
    final postup = tester.getRect(postupKarta);
    // Jeden sloupec přes celou šířku: závady, pod nimi postup.
    expect(zavady.top, lessThan(postup.top));
    expect(
      tester.getRect(find.byKey(const Key('zavady-karta'))).width,
      greaterThan(700),
    );
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
