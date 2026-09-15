import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/prijem/data/prijem_data_source.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/prijem.dart';
import 'package:renoworkshop/src/features/prijem/presentation/controllers/prijem_providers.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Zdroj, u kterého test určuje, kdy server odpoví.
class _PomalyZdroj extends FakeServiceOrderDataSource {
  _PomalyZdroj() : super([buildOrderDto(id: 'ZK-1')]);

  final List<Completer<void>> odpovedi = [];

  @override
  Future<Prijem> zmenPolozku(
    String orderId,
    String kod,
    ZmenaPolozky zmena,
  ) async {
    final odpoved = Completer<void>();
    odpovedi.add(odpoved);
    await odpoved.future;
    return super.zmenPolozku(orderId, kod, zmena);
  }
}

void main() {
  group('příjem', () {
    test('ze serveru přečte stav, položky a typ kontroly', () {
      final prijem = Prijem.fromJson({
        'status': 'in_progress',
        'startedBy': 'Jan Dvořák',
        'startedAt': '2026-09-15T08:00:00',
        'items': [
          {
            'code': 'sklo',
            'label': 'Čelní sklo',
            'type': 'check',
            'checked': true,
          },
          {'code': 'stk', 'label': 'STK', 'type': 'date', 'value': null},
          {
            'code': 'stara',
            'label': 'Lékárnička',
            'type': 'check',
            'required': false,
          },
        ],
      });

      expect(prijem.stav, StavPrijmu.rozpracovany);
      expect(prijem.polozky[1].typ, TypKontroly.datum);
      // Vyřazená kontrola se nepočítá.
      expect(prijem.pocetPovinnych, 2);
      expect(prijem.pocetVyplnenych, 1);
      expect(prijem.chybi, 1);
    });

    test('STK je vyplněná datem, ne zaškrtnutím', () {
      const stk = PolozkaPrijmu(
        kod: 'stk',
        nazev: 'STK',
        typ: TypKontroly.datum,
        splneno: true,
      );
      expect(stk.jeVyplnena, isFalse);
      expect(stk.copyWith(hodnota: '2027-05-31').jeVyplnena, isTrue);
    });

    test('změna posílá jen to, co se mění', () {
      expect(ZmenaPolozky.splneno(true).json, {'checked': true});
      expect(ZmenaPolozky.datum(DateTime(2027, 5, 31, 23, 59)).json, {
        'value': '2027-05-31',
      });
      expect(ZmenaPolozky.poznamka('  ').json, {'note': null});
    });
  });

  group('controller příjmu', () {
    ProviderContainer kontejner(FakeServiceOrderDataSource zdroj) {
      final container = ProviderContainer(
        overrides: [serviceOrderDataSourceProvider.overrideWithValue(zdroj)],
      );
      addTearDown(container.dispose);
      // autoDispose - bez posluchače by se příjem zahodil mezi kroky.
      container.listen(prijemZakazkyProvider('ZK-1'), (_, _) {});
      return container;
    }

    test('zaškrtnutí je vidět hned, ještě než server odpoví', () async {
      final zdroj = _PomalyZdroj();
      final container = kontejner(zdroj);
      await container.read(prijemZakazkyProvider('ZK-1').future);
      final controller = container.read(prijemZakazkyProvider('ZK-1').notifier);

      final hotovo = controller.zmen('brzdy', ZmenaPolozky.splneno(true));
      expect(
        container.read(prijemZakazkyProvider('ZK-1')).value!.pocetVyplnenych,
        1,
      );

      await Future<void>.delayed(Duration.zero);
      zdroj.odpovedi.single.complete();
      expect(await hotovo, isNull);
      expect(zdroj.prijmy.nacti('ZK-1').pocetVyplnenych, 1);
    });

    test(
      'odpověď na první změnu nesmaže druhou, která se ještě ukládá',
      () async {
        final zdroj = _PomalyZdroj();
        final container = kontejner(zdroj);
        await container.read(prijemZakazkyProvider('ZK-1').future);
        final controller = container.read(
          prijemZakazkyProvider('ZK-1').notifier,
        );

        final prvni = controller.zmen('brzdy', ZmenaPolozky.splneno(true));
        final druha = controller.zmen('motor', ZmenaPolozky.splneno(true));

        await Future<void>.delayed(Duration.zero);
        zdroj.odpovedi.first.complete();
        await prvni;
        // Server zatím zná jen brzdy, na obrazovce musí zůstat obojí.
        expect(
          container.read(prijemZakazkyProvider('ZK-1')).value!.pocetVyplnenych,
          2,
        );

        await Future<void>.delayed(Duration.zero);
        zdroj.odpovedi.last.complete();
        await druha;
        expect(
          container.read(prijemZakazkyProvider('ZK-1')).value!.pocetVyplnenych,
          2,
        );
      },
    );

    test('nepovedené uložení změnu vrátí a řekne proč', () async {
      final zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-1')]);
      final container = kontejner(zdroj);
      await container.read(prijemZakazkyProvider('ZK-1').future);
      zdroj.ulozeniPrijmuSelze = true;

      final chyba = await container
          .read(prijemZakazkyProvider('ZK-1').notifier)
          .zmen('brzdy', ZmenaPolozky.splneno(true));

      expect(chyba, 'Server neodpovídá.');
      expect(
        container.read(prijemZakazkyProvider('ZK-1')).value!.pocetVyplnenych,
        0,
      );
    });

    test('dokončit jde jen s vyplněným checklistem', () async {
      final zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-1')]);
      final container = kontejner(zdroj);
      await container.read(prijemZakazkyProvider('ZK-1').future);
      final controller = container.read(prijemZakazkyProvider('ZK-1').notifier);

      expect(await controller.dokonci(), isNotNull);

      for (final polozka in vychoziChecklist) {
        await controller.zmen(
          polozka.kod,
          polozka.typ == TypKontroly.datum
              ? ZmenaPolozky.datum(DateTime(2027, 5, 31))
              : ZmenaPolozky.splneno(true),
        );
      }
      expect(await controller.dokonci(), isNull);
      expect(
        container.read(prijemZakazkyProvider('ZK-1')).value!.stav,
        StavPrijmu.dokoncen,
      );

      // Dokončený je zamčený - změna se ani nepošle.
      final zmen = zdroj.pocetZmenPrijmu;
      await controller.zmen('brzdy', ZmenaPolozky.splneno(false));
      expect(zdroj.pocetZmenPrijmu, zmen);

      expect(await controller.znovuOtevri(), isNull);
      expect(
        container.read(prijemZakazkyProvider('ZK-1')).value!.stav,
        StavPrijmu.rozpracovany,
      );
    });
  });
}
