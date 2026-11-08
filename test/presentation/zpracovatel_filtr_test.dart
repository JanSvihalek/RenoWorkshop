import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/order_filter.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Filtr podle zpracovatele - kdo má vůz právě v rukou. Podle id
/// zaměstnance z Heliosu, s volbou „Nikdo" pro nepřevzaté zakázky.
void main() {
  final zakazky = [
    buildOrderDto(
      id: 'ZK-1',
      assignee: {'id': 501, 'name': 'Dvořák Jan'},
    ).toDomain(),
    buildOrderDto(
      id: 'ZK-2',
      assignee: {'id': 502, 'name': 'Kříž Martin'},
    ).toDomain(),
    buildOrderDto(id: 'ZK-3').toDomain(),
  ];

  List<String> cisla(OrderFilter filtr) =>
      filtr.apply(zakazky).map((z) => z.id).toList();

  test('filtr podle zpracovatele a „Nikdo"', () {
    expect(cisla(const OrderFilter(zpracovatelIds: {502})), ['ZK-2']);
    expect(cisla(const OrderFilter(zpracovatelIds: {OrderFilter.nikdo})), [
      'ZK-3',
    ]);
    expect(cisla(const OrderFilter()), hasLength(3));
    // Víc lidí naráz, i s „Nikdo".
    expect(cisla(const OrderFilter(zpracovatelIds: {502, OrderFilter.nikdo})), [
      'ZK-2',
      'ZK-3',
    ]);

    const filtr = OrderFilter(zpracovatelIds: {501});
    expect(filtr.isActive, isTrue);
    expect(filtr.activeCount, 1);
    expect(filtr.copyWith(zpracovatelIds: {}), const OrderFilter());
  });

  ProviderContainer kontejner(Nastaveni nastaveni) {
    final container = ProviderContainer(
      overrides: [
        nastaveniUlozisteProvider.overrideWithValue(
          PametoveNastaveni(nastaveni),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('výchozí zpracovatel z nastavení se propíše do filtru', () {
    final container = kontejner(
      const Nastaveni(
        vychoziZpracovatele: [502],
        jmenaZpracovatelu: {502: 'Kříž Martin'},
      ),
    );
    expect(container.read(orderFilterProvider).zpracovatelIds, {502});
    expect(container.read(nastaveniProvider).maVychoziFiltr, isTrue);

    // „Vymazat" ve výchozím filtru shodí i zpracovatele.
    container.read(nastaveniProvider.notifier).zrusVychoziFiltr();
    expect(container.read(orderFilterProvider).zpracovatelIds, isEmpty);
    expect(container.read(nastaveniProvider).jmenaZpracovatelu, isEmpty);
  });

  test('výchozí zpracovatel přežije restart a po zrušení zmizí', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final uloziste = SharedPreferencesNastaveni(prefs);

    await uloziste.uloz(
      const Nastaveni(
        vychoziZpracovatele: [502, OrderFilter.nikdo],
        jmenaZpracovatelu: {502: 'Kříž Martin'},
      ),
    );
    final nactene = SharedPreferencesNastaveni(prefs).nacti();
    expect(nactene.vychoziZpracovatele, [502, OrderFilter.nikdo]);
    expect(nactene.jmenaZpracovatelu, {502: 'Kříž Martin'});

    await uloziste.uloz(const Nastaveni());
    expect(
      SharedPreferencesNastaveni(prefs).nacti().vychoziZpracovatele,
      isEmpty,
    );
  });

  test(
    'výchozí filtr ze starší verze (jedna hodnota) se načte jako seznam',
    () async {
      SharedPreferences.setMockInitialValues({
        'nastaveni.vychoziUtvar': '11215',
        'nastaveni.vychoziZpracovatel': 502,
        'nastaveni.vychoziZpracovatelJmeno': 'Kříž Martin',
      });
      final prefs = await SharedPreferences.getInstance();
      final nactene = SharedPreferencesNastaveni(prefs).nacti();
      expect(nactene.vychoziUtvary, ['11215']);
      expect(nactene.vychoziZpracovatele, [502]);
      expect(nactene.jmenaZpracovatelu, {502: 'Kříž Martin'});

      // Po uložení se staré klíče smažou, platí nové seznamy.
      await SharedPreferencesNastaveni(prefs).uloz(nactene);
      expect(prefs.getString('nastaveni.vychoziUtvar'), isNull);
      expect(SharedPreferencesNastaveni(prefs).nacti().vychoziUtvary, [
        '11215',
      ]);
    },
  );
}
