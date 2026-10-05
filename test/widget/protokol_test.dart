import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/prace_s_dokumenty.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/order_detail_screen.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Prohlížeč bez zařízení - jen si pamatuje, co se otevřelo.
class _FalesnaPrace implements PraceSDokumenty {
  final List<(String, Uint8List)> otevrene = [];

  @override
  Future<List<VybranySoubor>> vyber() async => const [];

  @override
  Future<void> otevri(String nazev, Uint8List data) async =>
      otevrene.add((nazev, data));
}

/// Karta Protokol zakázky v detailu: vytvoří PDF ve složce zakázky hned
/// a otevře ho.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;
  late _FalesnaPrace prace;

  Future<void> otevriDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]);
    prace = _FalesnaPrace();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          praceSDokumentyProvider.overrideWithValue(prace),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OrderDetailScreen(orderId: 'ZK-26-0001', onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('otevrit-protokol')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
  }

  testWidgets('tlačítko protokol vytvoří a otevře', (tester) async {
    await otevriDetail(tester);

    await tester.tap(find.byKey(const Key('otevrit-protokol')));
    await tester.pumpAndSettle();

    expect(zdroj.vytvorenychProtokolu, 1);
    expect(prace.otevrene.single.$1, 'Protokol ZK-26-0001.pdf');
    expect(String.fromCharCodes(prace.otevrene.single.$2), '%PDF');
  });

  testWidgets('otevřený protokol na serveru řekne proč', (tester) async {
    await otevriDetail(tester);
    zdroj.protokolSelze =
        'Protokol má někdo otevřený, přepsat ho teď nejde. '
        'Zavřete ho a zkuste to znovu.';

    await tester.tap(find.byKey(const Key('otevrit-protokol')));
    await tester.pumpAndSettle();

    expect(find.textContaining('má někdo otevřený'), findsOneWidget);
    expect(prace.otevrene, isEmpty);
  });
}
