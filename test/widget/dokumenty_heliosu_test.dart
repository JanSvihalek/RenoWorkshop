import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/fotodokumentace/domain/entities/dokument.dart';
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

/// Karta Dokumenty Helios v detailu zakázky - zakázkový list z EDM.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;
  late _FalesnaPrace prace;

  final zakazkovyList = Dokument.fromJson({
    'id': 'helios-478338',
    'name': 'Zak-list-Z1212607793-29.09.2026-10-39-50_1.pdf',
    'folder': null,
    'size': null,
    'modifiedAt': '2026-09-29T10:39:50',
    'source': 'helios',
  });

  Future<void> otevriDetail(
    WidgetTester tester, {
    List<Dokument> dokumenty = const [],
    String? chyba,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]);
    zdroj.dokumentyHeliosuZakazek['ZK-26-0001'] = dokumenty;
    zdroj.dokumentyHeliosuSelzou = chyba;
    for (final dokument in dokumenty) {
      zdroj.bajtyDokumentu[dokument.id] = Uint8List.fromList([7, 7]);
    }
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
  }

  Finder vKarte(Finder finder) => find.descendant(
    of: find.byKey(const Key('dokumenty-heliosu')),
    matching: finder,
  );

  testWidgets('zakázkový list je v detailu a klepnutím se otevře', (
    tester,
  ) async {
    await otevriDetail(tester, dokumenty: [zakazkovyList]);

    expect(vKarte(find.text('DOKUMENTY HELIOS')), findsOneWidget);
    expect(
      vKarte(find.text('Zak-list-Z1212607793-29.09.2026-10-39-50_1.pdf')),
      findsOneWidget,
    );
    expect(vKarte(find.text('1 dokument')), findsOneWidget);
    expect(vKarte(find.textContaining('29. 9. 2026')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dokument-heliosu-helios-478338')));
    await tester.pumpAndSettle();

    expect(
      prace.otevrene.single.$1,
      'Zak-list-Z1212607793-29.09.2026-10-39-50_1.pdf',
    );
    expect(prace.otevrene.single.$2, [7, 7]);
  });

  testWidgets('zakázka bez dokumentů v Heliosu to řekne', (tester) async {
    await otevriDetail(tester);

    expect(
      vKarte(find.text('Helios u zakázky žádné dokumenty nemá.')),
      findsOneWidget,
    );
  });

  testWidgets('nedostupný Helios ukáže chybu a jde zkusit znovu', (
    tester,
  ) async {
    await otevriDetail(tester, chyba: 'Dokumenty z Heliosu teď nejdou načíst.');
    expect(
      vKarte(find.text('Dokumenty z Heliosu se nepodařilo načíst.')),
      findsOneWidget,
    );

    zdroj.dokumentyHeliosuSelzou = null;
    zdroj.dokumentyHeliosuZakazek['ZK-26-0001'] = [zakazkovyList];
    zdroj.bajtyDokumentu[zakazkovyList.id] = Uint8List.fromList([1]);
    await tester.tap(find.byKey(const Key('dokumenty-heliosu-znovu')));
    await tester.pumpAndSettle();

    expect(
      vKarte(find.text('Zak-list-Z1212607793-29.09.2026-10-39-50_1.pdf')),
      findsOneWidget,
    );
  });
}
