import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/domain/marketingova_akce.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_screen.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Marketingové akce: na tabletu vedle seznamu zakázek, na telefonu pruh
/// nad seznamem. Zadávat smí jen správce akcí.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  final dnes = DateTime(2026, 10, 14);
  late FakeServiceOrderDataSource zdroj;

  final zimni = MarketingovaAkce(
    id: 'a1',
    nazev: 'Zimní prohlídka -20 %',
    text: 'Kontrola před zimou, sleva na práci.',
    od: DateTime(2026, 10, 1),
    do_: DateTime(2026, 11, 30),
  );
  final sterace = MarketingovaAkce(
    id: 'a2',
    nazev: 'Stěrače zdarma',
    text: '',
    od: DateTime(2026, 9, 20),
    do_: DateTime(2026, 10, 17),
  );
  final prezuti = MarketingovaAkce(
    id: 'a3',
    nazev: 'Přezutí s uskladněním',
    text: '',
    od: DateTime(2026, 10, 25),
    do_: DateTime(2026, 11, 20),
  );

  Future<void> spust(
    WidgetTester tester, {
    required Size velikost,
    bool spravce = false,
    List<MarketingovaAkce>? akce,
  }) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..akce = [
        ...(akce ?? [zimni, sterace, prezuti]),
      ]
      ..spravceAkci = spravce;
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
          dnesProvider.overrideWithValue(dnes),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  const tablet = Size(1280, 1000);
  const telefon = Size(400, 900);

  testWidgets('na tabletu jsou akce vedle seznamu, technik je jen čte', (
    tester,
  ) async {
    await spust(tester, velikost: tablet);

    expect(find.byKey(const Key('akce-panel')), findsOneWidget);
    expect(find.text('Vyberte zakázku ze seznamu'), findsOneWidget);
    expect(find.byKey(const Key('akce-osa')), findsOneWidget);
    expect(find.byKey(const Key('akce-a1')), findsOneWidget);
    expect(find.text('Platí ještě 48 dní'), findsOneWidget);
    expect(find.text('Končí za 3 dny'), findsOneWidget);
    expect(find.text('Začne za 11 dní'), findsOneWidget);
    expect(find.text('Kontrola před zimou, sleva na práci.'), findsOneWidget);

    expect(find.byKey(const Key('akce-pridat')), findsNothing);
    expect(find.byKey(const Key('akce-upravit-a1')), findsNothing);
    // Na tabletu je pruh nad seznamem zbytečný - akce jsou vedle.
    expect(find.byKey(const Key('akce-pruh')), findsNothing);
  });

  testWidgets('správce akci přidá', (tester) async {
    await spust(tester, velikost: tablet, spravce: true, akce: []);
    expect(find.byKey(const Key('akce-zadne')), findsOneWidget);

    await tester.tap(find.byKey(const Key('akce-pridat')));
    await tester.pumpAndSettle();
    final ulozit = find.byKey(const Key('akce-ulozit'));
    bool lze() => tester.widget<FilledButton>(ulozit).onPressed != null;

    await tester.enterText(
      find.byKey(const Key('akce-nazev')),
      'Zimní prohlídka',
    );
    await tester.enterText(find.byKey(const Key('akce-text')), 'Sleva 20 %.');
    await tester.pump();
    expect(lze(), isFalse, reason: 'bez platnosti se akce neuloží');

    await tester.tap(find.byKey(const Key('akce-platnost')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').first);
    await tester.pump();
    await tester.tap(find.text('31').first);
    await tester.pump();
    await tester.tap(find.text('Hotovo'));
    await tester.pumpAndSettle();
    expect(find.text('20. 10. – 31. 10. 2026'), findsOneWidget);
    expect(lze(), isTrue);

    await tester.tap(ulozit);
    await tester.pumpAndSettle();

    expect(zdroj.akce.single.nazev, 'Zimní prohlídka');
    expect(zdroj.akce.single.od, DateTime(2026, 10, 20));
    expect(zdroj.akce.single.do_, DateTime(2026, 10, 31));
    expect(find.text('Zimní prohlídka'), findsWidgets);
    expect(find.text('Začne za 6 dní'), findsOneWidget);
  });

  testWidgets('správce akci upraví a smaže', (tester) async {
    await spust(tester, velikost: tablet, spravce: true);

    await tester.tap(find.byKey(const Key('akce-upravit-a1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('akce-nazev')),
      'Zimní prohlídka -25 %',
    );
    await tester.tap(find.byKey(const Key('akce-ulozit')));
    await tester.pumpAndSettle();
    expect(
      zdroj.akce.firstWhere((a) => a.id == 'a1').nazev,
      'Zimní prohlídka -25 %',
    );

    await tester.tap(find.byKey(const Key('akce-upravit-a2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('akce-smazat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('akce-smazat-potvrdit')));
    await tester.pumpAndSettle();

    expect(zdroj.akce.map((a) => a.id), isNot(contains('a2')));
    expect(find.byKey(const Key('akce-a2')), findsNothing);
  });

  testWidgets('na telefonu pruh nad seznamem otevře přehled', (tester) async {
    await spust(tester, velikost: telefon);

    final pruh = find.byKey(const Key('akce-pruh'));
    expect(pruh, findsOneWidget);
    // Platí dvě, třetí teprve začne.
    expect(
      find.descendant(
        of: pruh,
        matching: find.textContaining(
          '2 marketingové akce',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(pruh);
    await tester.pumpAndSettle();
    expect(find.byType(AkceScreen), findsOneWidget);
    expect(find.byKey(const Key('akce-a3')), findsOneWidget);
  });

  testWidgets('bez platné akce technik pruh nevidí, správce ano', (
    tester,
  ) async {
    await spust(tester, velikost: telefon, akce: [prezuti]);
    expect(find.byKey(const Key('akce-pruh')), findsNothing);
  });

  testWidgets('správce vidí pruh i bez platné akce - jinak by neměl kudy '
      'přidat', (tester) async {
    await spust(tester, velikost: telefon, spravce: true, akce: [prezuti]);
    final pruh = find.byKey(const Key('akce-pruh'));
    expect(pruh, findsOneWidget);
    expect(
      find.descendant(
        of: pruh,
        matching: find.textContaining('Marketingové akce', findRichText: true),
      ),
      findsOneWidget,
    );
  });
}
