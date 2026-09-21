import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Na širokém tabletu má detail dva sloupce: vlevo co se čte, vpravo co
/// se zapisuje. Na telefonu i v rozděleném zobrazení zůstává jeden.
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

  testWidgets('na širokém tabletu je zápis vpravo od údajů', (tester) async {
    await otevri(tester, const Size(1280, 800));

    final vlevo = tester.getRect(fotkyKarta);
    final vpravo = tester.getRect(postupKarta);
    // Fotodokumentace (ke čtení) končí dřív, než začíná postup (zápis).
    expect(vlevo.right, lessThanOrEqualTo(vpravo.left));
    // Každá karta je ve své polovině obrazovky.
    expect(vlevo.right, lessThan(640));
    expect(vpravo.left, greaterThan(640));
  });

  testWidgets('na tabletu jsou závady vpravo pod poznámkami', (tester) async {
    // Vysoký, ať je celý pravý sloupec postavený najednou.
    await otevri(tester, const Size(1280, 2400));

    final zavady = tester.getRect(find.text('ZÁVADY/ÚKONY'));
    final poznamky = tester.getRect(find.text('POZNÁMKY'));
    expect(zavady.left, greaterThan(640));
    expect(zavady.top, greaterThan(poznamky.top));
  });

  testWidgets('na telefonu jsou karty pod sebou', (tester) async {
    await otevri(tester, const Size(800, 1400));

    final postup = tester.getRect(postupKarta);
    final fotky = tester.getRect(fotkyKarta);
    // Jeden sloupec: fotodokumentace je pod postupem a přes celou šířku.
    expect(fotky.top, greaterThan(postup.top));
    expect(fotky.width, greaterThan(700));
  });
}
