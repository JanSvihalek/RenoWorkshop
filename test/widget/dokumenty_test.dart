import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/fotodokumentace/domain/entities/dokument.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/prace_s_dokumenty.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/screens/fotodokumentace_screen.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Výběr souborů a prohlížeč bez zařízení.
class _FalesnaPrace implements PraceSDokumenty {
  List<VybranySoubor> vybrane = const [];
  final List<(String, Uint8List)> otevrene = [];

  @override
  Future<List<VybranySoubor>> vyber() async => vybrane;

  @override
  Future<void> otevri(String nazev, Uint8List data) async =>
      otevrene.add((nazev, data));
}

VybranySoubor _soubor(String nazev, List<int> data, {int? velikost}) =>
    VybranySoubor(
      nazev: nazev,
      velikost: velikost ?? data.length,
      nacti: () async => Uint8List.fromList(data),
    );

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;
  late _FalesnaPrace prace;

  Future<void> otevri(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
  }) async {
    zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]);
    prace = _FalesnaPrace();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(nastaveni),
          ),
          praceSDokumentyProvider.overrideWithValue(prace),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: FotodokumentaceScreen(orderId: 'ZK-26-0001', onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Karta dokumentů je až za kategoriemi fotek.
  Future<void> dolu(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('nahrat-dokument')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nahraný dokument jde na server a objeví se v seznamu', (
    tester,
  ) async {
    await otevri(tester, nastaveni: const Nastaveni(slozkaFotek: 'KCP'));
    await dolu(tester);
    expect(find.text('PDF, skeny, tabulky'), findsOneWidget);

    prace.vybrane = [
      _soubor('Předávací protokol.pdf', [1, 2, 3]),
    ];
    await tester.tap(find.byKey(const Key('nahrat-dokument')));
    await tester.pumpAndSettle();

    expect(zdroj.bajtyDokumentu['dok-1'], [1, 2, 3]);
    // Do stejné pobočky jako fotky.
    expect(zdroj.pobockaDokumentu, 'KCP');
    expect(find.text('Předávací protokol.pdf'), findsOneWidget);
    expect(find.text('1 dokument'), findsOneWidget);
  });

  testWidgets('ručně vložený soubor je vidět a otevře se', (tester) async {
    await otevri(tester);
    zdroj.dokumenty['ZK-26-0001'] = [
      Dokument(
        id: 'rucni',
        nazev: 'Zakázkový list.pdf',
        velikost: 2516582,
        zmenenoAt: DateTime(2026, 9, 21, 9, 15),
        nahranyZAplikace: false,
      ),
    ];
    zdroj.bajtyDokumentu['rucni'] = Uint8List.fromList([9, 9]);

    // Stažení dolů načte znovu i dokumenty - kolega je mezitím vložil.
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    await dolu(tester);

    expect(find.text('Zakázkový list.pdf'), findsOneWidget);
    expect(find.textContaining('2,4 MB'), findsOneWidget);
    expect(find.textContaining('vloženo ve složce'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dokument-rucni')));
    await tester.pumpAndSettle();

    expect(prace.otevrene.single.$1, 'Zakázkový list.pdf');
    expect(prace.otevrene.single.$2, [9, 9]);
  });

  testWidgets('příliš velký soubor se nenahraje, ostatní ano', (tester) async {
    await otevri(tester);
    await dolu(tester);

    prace.vybrane = [
      _soubor('sken.pdf', [1], velikost: maxVelikostDokumentu + 1),
      _soubor('nabidka.xlsx', [2]),
    ];
    await tester.tap(find.byKey(const Key('nahrat-dokument')));
    await tester.pumpAndSettle();

    expect(find.text('sken.pdf je větší než 25,0 MB.'), findsOneWidget);
    expect(zdroj.dokumenty['ZK-26-0001']!.map((d) => d.nazev), [
      'nabidka.xlsx',
    ]);
  });

  testWidgets('odmítnutí serverem se ukáže', (tester) async {
    await otevri(tester);
    await dolu(tester);
    zdroj.nahravaniDokumentuSelze = 'Tento typ souboru nahrát nejde.';

    prace.vybrane = [
      _soubor('protokol.pdf', [1]),
    ];
    await tester.tap(find.byKey(const Key('nahrat-dokument')));
    await tester.pumpAndSettle();

    expect(find.text('Tento typ souboru nahrát nejde.'), findsOneWidget);
    expect(find.text('PDF, skeny, tabulky'), findsOneWidget);
  });

  test('velikost souboru česky', () {
    expect(velikostSouboru(500), '1 kB');
    expect(velikostSouboru(2516582), '2,4 MB');
    expect(pocetDokumentu(3), '3 dokumenty');
    expect(pocetDokumentu(5), '5 dokumentů');
  });
}
