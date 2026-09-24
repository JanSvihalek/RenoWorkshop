import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renoworkshop/src/app/app.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Příjem i hledání vozu začínají SPZ, takže klepnutí na záložku rovnou
/// otevře skener. Musí z něj jít rychle k ručnímu psaní a nesmí se
/// otevírat pořád dokola.
void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<void> spust(
    WidgetTester tester, {
    Nastaveni nastaveni = const Nastaveni(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            PlaceholderAuthRepository(
              ssoDelay: Duration.zero,
              biometricDelay: Duration.zero,
            ),
          ),
          serviceOrderDataSourceProvider.overrideWithValue(
            FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-26-0001')]),
          ),
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(nastaveni),
          ),
        ],
        child: const RenoWorkshopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přihlásit se přes Microsoft'));
    await tester.pumpAndSettle();
  }

  /// Ne pumpAndSettle: kamera se v testu nespustí a načítací kolečko
  /// skeneru by se točilo navždy. Stačí pár snímků na přechod obrazovky.
  Future<void> dojed(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> klepniNa(WidgetTester tester, String zalozka) async {
    await tester.tap(find.text(zalozka).last);
    await dojed(tester);
  }

  testWidgets('klepnutí na Příjem otevře skener s nápovědou', (tester) async {
    await spust(tester);
    await klepniNa(tester, 'Příjem');

    expect(find.byType(SkenerScreen), findsOneWidget);
    expect(
      find.text('Naskenujte SPZ nebo VIN vozidla pro vyhledání záznamu'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('skener-rucne')), findsOneWidget);
  });

  testWidgets('klepnutí na Vozidla otevře skener', (tester) async {
    await spust(tester);
    await klepniNa(tester, 'Vozidla');

    expect(find.byType(SkenerScreen), findsOneWidget);
  });

  testWidgets('Zadat ručně zavře skener a dá kurzor do pole', (tester) async {
    await spust(tester);
    await klepniNa(tester, 'Příjem');

    await tester.tap(find.byKey(const Key('skener-rucne')));
    await dojed(tester);

    expect(find.byType(SkenerScreen), findsNothing);
    expect(find.byType(PrijemScreen), findsOneWidget);
    final pole = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(PrijemScreen),
        matching: find.byType(EditableText),
      ),
    );
    expect(pole.focusNode.hasFocus, isTrue);
  });

  testWidgets('zavřený skener se sám znovu neotevře', (tester) async {
    await spust(tester);
    await klepniNa(tester, 'Příjem');

    await tester.tap(find.byTooltip('Zavřít'));
    await dojed(tester);

    // Zůstane na Příjmu, žádný nový skener.
    expect(find.byType(SkenerScreen), findsNothing);
    expect(find.byType(PrijemScreen), findsOneWidget);
  });

  testWidgets('vypnuté v nastavení se skener sám neotevře', (tester) async {
    await spust(tester, nastaveni: const Nastaveni(skenovatPoOtevreni: false));
    await klepniNa(tester, 'Příjem');

    expect(find.byType(SkenerScreen), findsNothing);
    expect(find.byType(PrijemScreen), findsOneWidget);
  });

  testWidgets('skener ze seznamu zakázek nemá Zadat ručně', (tester) async {
    final semantika = tester.ensureSemantics();
    await spust(tester);

    await tester.tap(find.bySemanticsLabel('Načíst VIN nebo SPZ fotoaparátem'));
    await dojed(tester);

    // Pole hledání zakázek je vidět hned po zavření - tlačítko je navíc.
    expect(find.byType(SkenerScreen), findsOneWidget);
    expect(find.byKey(const Key('skener-rucne')), findsNothing);
    semantika.dispose();
  });
}
