import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/akce/domain/marketingova_akce.dart';
import 'package:renoworkshop/src/features/akce/domain/technicka_kampan.dart';
import 'package:renoworkshop/src/features/akce/presentation/akce_providers.dart';
import 'package:renoworkshop/src/features/akce/presentation/kampane_screen.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/kampan_vozidla.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Technické kampaně BMW: druhý řádek pruhu nad seznamem zakázek, panel
/// na tabletu, obrazovka na telefonu a štítek u vozu v detailu zakázky.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  late FakeServiceOrderDataSource zdroj;

  const airbag = TechnickaKampan(
    id: 'k1',
    kod: '0061960500',
    nazev: 'Kontrola airbagu spolujezdce',
    text: 'Dotáhnout šrouby modulu airbagu.',
  );

  Future<void> spust(
    WidgetTester tester, {
    required Size velikost,
    bool spravce = false,
    List<TechnickaKampan> kampane = const [airbag],
    List<KampanVozidla> kampaneVozu = const [],
  }) async {
    tester.view.physicalSize = velikost;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    zdroj =
        FakeServiceOrderDataSource([
            buildOrderDto(technicalCampaigns: kampaneVozu),
          ])
          ..akce = [
            MarketingovaAkce(
              id: 'a1',
              nazev: 'Zimní prohlídka',
              text: '',
              od: DateTime(2026, 10, 1),
              do_: DateTime(2026, 11, 30),
            ),
          ]
          ..kampane = [...kampane]
          ..vinyKampani = {
            for (final k in kampane) k.id!: ['F123456', 'G654321'],
          }
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
          dnesProvider.overrideWithValue(DateTime(2026, 10, 14)),
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

  testWidgets('na telefonu jsou nad seznamem dva řádky, kampaně se otevřou', (
    tester,
  ) async {
    await spust(tester, velikost: telefon);

    expect(find.byKey(const Key('akce-pruh')), findsOneWidget);
    final pruh = find.byKey(const Key('kampane-pruh'));
    expect(
      find.descendant(
        of: pruh,
        matching: find.textContaining(
          '1 technická kampaň · Kontrola airbagu',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(pruh);
    await tester.pumpAndSettle();
    expect(find.byType(KampaneScreen), findsOneWidget);
    expect(find.text('2 VINy'), findsOneWidget);
    expect(find.text('0061960500'), findsOneWidget);
    expect(find.byKey(const Key('kampane-pridat')), findsNothing);
  });

  testWidgets('bez kampaní technik řádek nevidí', (tester) async {
    await spust(tester, velikost: telefon, kampane: []);
    expect(find.byKey(const Key('akce-pruh')), findsOneWidget);
    expect(find.byKey(const Key('kampane-pruh')), findsNothing);
  });

  testWidgets('na tabletu řádek bez vybrané zakázky přepne panel, u zakázky '
      'ho vysune', (tester) async {
    await spust(tester, velikost: tablet);
    expect(find.byKey(const Key('akce-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kampane-pruh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kampane-panel')), findsOneWidget);
    expect(find.byKey(const Key('akce-panel')), findsNothing);

    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kampan-k1')), findsNothing);

    // Kampaně vysunout, pak přepnout na akce, pak stejným řádkem zavřít.
    await tester.tap(find.byKey(const Key('kampane-pruh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kampan-k1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('akce-pruh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kampan-k1')), findsNothing);
    expect(find.byKey(const Key('akce-a1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('akce-pruh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('akce-a1')), findsNothing);
  });

  testWidgets('kampaň, která se vozu týká, je v hlavičce detailu', (
    tester,
  ) async {
    await spust(
      tester,
      velikost: tablet,
      kampaneVozu: const [
        KampanVozidla(
          id: 'k1',
          kod: '0061960500',
          nazev: 'Kontrola airbagu spolujezdce',
          text: 'Dotáhnout šrouby modulu airbagu.',
        ),
      ],
    );
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();

    final stitek = find.byKey(const Key('kampan-vozu-k1'));
    expect(stitek, findsOneWidget);
    expect(
      find.descendant(
        of: stitek,
        matching: find.text('0061960500 · Kontrola airbagu spolujezdce'),
      ),
      findsOneWidget,
    );

    await tester.tap(stitek);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Technická kampaň 0061960500\n\nDotáhnout šrouby modulu airbagu.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('bez kampaně štítek v detailu není', (tester) async {
    await spust(tester, velikost: tablet);
    await tester.tap(find.text('1AA 1111'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kampan-vozu-k1')), findsNothing);
  });

  testWidgets('správce kampaň přidá - s neplatným VINem neuloží', (
    tester,
  ) async {
    await spust(tester, velikost: tablet, spravce: true, kampane: []);
    await tester.tap(find.byKey(const Key('kampane-pruh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kampane-zadne')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kampane-pridat')));
    await tester.pumpAndSettle();
    final ulozit = find.byKey(const Key('kampan-ulozit'));
    bool lze() => tester.widget<FilledButton>(ulozit).onPressed != null;

    await tester.enterText(find.byKey(const Key('kampan-kod')), '0032760300');
    await tester.enterText(
      find.byKey(const Key('kampan-nazev')),
      'Software motoru',
    );
    await tester.enterText(
      find.byKey(const Key('kampan-viny')),
      'VIN\nWBA3A5C51DF123456\nf123456',
    );
    await tester.pump();
    expect(find.text('Rozpoznáno 2 VINy'), findsOneWidget);
    expect(find.byKey(const Key('kampan-neplatne')), findsOneWidget);
    expect(lze(), isFalse, reason: 'neplatný VIN musí správce opravit');

    await tester.enterText(
      find.byKey(const Key('kampan-viny')),
      'WBA3A5C51DF123456\nf123456',
    );
    await tester.pump();
    expect(find.byKey(const Key('kampan-neplatne')), findsNothing);
    expect(lze(), isTrue);

    await tester.tap(ulozit);
    await tester.pumpAndSettle();

    final ulozena = zdroj.kampane.single;
    expect(ulozena.kod, '0032760300');
    expect(ulozena.nazev, 'Software motoru');
    expect(zdroj.vinyKampani[ulozena.id], ['WBA3A5C51DF123456', 'F123456']);
    expect(find.text('2 VINy'), findsOneWidget);
  });

  testWidgets('správce upraví VINy a kampaň smaže', (tester) async {
    await spust(tester, velikost: tablet, spravce: true);
    await tester.tap(find.byKey(const Key('kampane-pruh')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kampan-upravit-k1')));
    await tester.pumpAndSettle();
    // VINy se do okna načtou ze serveru.
    expect(find.text('Rozpoznáno 2 VINy'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('kampan-viny')), 'F123456');
    await tester.tap(find.byKey(const Key('kampan-ulozit')));
    await tester.pumpAndSettle();
    expect(zdroj.vinyKampani['k1'], ['F123456']);
    expect(find.text('1 VIN'), findsOneWidget);

    await tester.tap(find.byKey(const Key('kampan-upravit-k1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kampan-smazat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kampan-smazat-potvrdit')));
    await tester.pumpAndSettle();
    expect(zdroj.kampane, isEmpty);
    expect(find.byKey(const Key('kampan-k1')), findsNothing);
  });
}
