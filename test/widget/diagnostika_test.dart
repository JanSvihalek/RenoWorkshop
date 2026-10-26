import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/diagnostika/domain/diagnostika.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/prace_s_dokumenty.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Diagnostické protokoly BMW ISPI v detailu zakázky.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  test('z API: protokol a soubor', () {
    final p = ProtokolDiagnostiky.fromJson({
      'id': '7',
      'at': '2026-10-21T09:15:00',
      'source': 'Brno',
      'mainFile': {'id': 'hlavni', 'name': 'report.pdf'},
    });
    expect(p.cas, DateTime(2026, 10, 21, 9, 15));
    expect(p.hlavniNazev, 'report.pdf');
    final s = SouborDiagnostiky.fromJson({
      'id': 'x',
      'name': 'Testplan.pdf',
      'folder': 'ISTA-Data',
      'size': 2400000,
      'main': false,
    });
    expect(s.slozka, 'ISTA-Data');
    expect(velikostSouboru(s.velikost), '2,3 MB');
    expect(velikostSouboru(196000), '191 kB');
  });

  testWidgets('detail: otevře finální report, podrobné po rozbalení', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final otevrene = <String>[];
    final zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..diagnostika = {
        'ZK-26-0001': [
          ProtokolDiagnostiky(
            id: '7',
            cas: DateTime(2026, 10, 21, 9, 15),
            zdroj: 'Brno',
            hlavniId: 'hlavni',
            hlavniNazev: 'report.pdf',
          ),
        ],
      }
      ..souboryDiagnostiky = {
        '7': const [
          SouborDiagnostiky(id: 'hlavni', nazev: 'report.pdf', hlavni: true),
          SouborDiagnostiky(
            id: 'ista',
            nazev: 'Testplan.pdf',
            slozka: 'ISTA-Data',
            velikost: 2400000,
          ),
        ],
      };
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
          praceSDokumentyProvider.overrideWithValue(_ZaznamOtevreni(otevrene)),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    final karta = find.byKey(const Key('diagnostika-karta'));
    await tester.scrollUntilVisible(
      karta,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('diagnostika-7')));
    await tester.pumpAndSettle();
    expect(zdroj.stazeneDiagnostiky.last, ('7', 'hlavni'));
    expect(otevrene.last, 'report.pdf');

    await tester.tap(find.byKey(const Key('diagnostika-podrobne-7')));
    await tester.pumpAndSettle();
    expect(find.text('Testplan.pdf'), findsOneWidget);
    expect(find.text('ISTA-Data · 2,3 MB'), findsOneWidget);
    await tester.tap(find.byKey(const Key('diagnostika-soubor-ista')));
    await tester.pumpAndSettle();
    expect(zdroj.stazeneDiagnostiky.last, ('7', 'ista'));
  });
}

/// Otevření souboru jen zapíše jeho název.
class _ZaznamOtevreni implements PraceSDokumenty {
  _ZaznamOtevreni(this.otevrene);

  final List<String> otevrene;

  @override
  Future<List<VybranySoubor>> vyber() async => const [];

  @override
  Future<void> otevri(String nazev, Uint8List data) async =>
      otevrene.add(nazev);
}
