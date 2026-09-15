import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

void main() {
  /// Skener bez kamery - v testu se nespustí, ovládání se ale vykreslí
  /// stejně.
  Future<void> otevri(WidgetTester tester, UmisteniSpouste spoust) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(Nastaveni(spoust: spoust)),
          ),
        ],
        child: MaterialApp(
          home: SkenerScreen(onNalezeno: (_) {}, onBack: () {}),
        ),
      ),
    );
    // Ne pumpAndSettle: kamera se v testu nespustí a načítací kolečko by
    // se točilo navždy. Ovládání je vykreslené hned v prvním snímku.
    await tester.pump();
  }

  Offset stredSpouste(WidgetTester tester) =>
      tester.getCenter(find.bySemanticsLabel('Vyfotit'));

  testWidgets('výchozí spoušť je dole uprostřed', (tester) async {
    final semantika = tester.ensureSemantics();
    await otevri(tester, UmisteniSpouste.dole);

    final stred = stredSpouste(tester);
    expect(stred.dx, closeTo(640, 1));
    expect(stred.dy, greaterThan(600));
    semantika.dispose();
  });

  testWidgets('spoušť vpravo je u pravého kraje v polovině výšky', (
    tester,
  ) async {
    final semantika = tester.ensureSemantics();
    await otevri(tester, UmisteniSpouste.vpravo);

    final stred = stredSpouste(tester);
    expect(stred.dx, greaterThan(1100));
    expect(stred.dy, closeTo(400, 80));
    semantika.dispose();
  });

  testWidgets('spoušť vlevo je u levého kraje', (tester) async {
    final semantika = tester.ensureSemantics();
    await otevri(tester, UmisteniSpouste.vlevo);

    expect(stredSpouste(tester).dx, lessThan(180));
    semantika.dispose();
  });
}
