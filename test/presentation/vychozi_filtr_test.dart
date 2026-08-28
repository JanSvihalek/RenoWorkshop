import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

/// Výchozí filtr z nastavení musí platit hned při otevření seznamu -
/// jinak by mechanik pokaždé viděl zakázky celé firmy a musel filtrovat
/// ručně.
void main() {
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

  test('bez nastavení se seznam otevře nefiltrovaný', () {
    final filter = kontejner(const Nastaveni()).read(orderFilterProvider);

    expect(filter.branchCode, isNull);
    expect(filter.isActive, isFalse);
  });

  test('výchozí pobočka a útvar se propíšou do filtru', () {
    final filter = kontejner(
      const Nastaveni(vychoziPobocka: '12', vychoziUtvar: '12100'),
    ).read(orderFilterProvider);

    expect(filter.branchCode, '12');
    expect(filter.departmentCode, '12100');
  });

  test('změna nastavení překreslí i právě otevřený seznam', () {
    final container = kontejner(const Nastaveni());

    expect(container.read(orderFilterProvider).branchCode, isNull);
    container.read(nastaveniProvider.notifier).zmenVychoziPobocku('13');

    expect(container.read(orderFilterProvider).branchCode, '13');
  });

  test('zrušení filtrů vrací na výchozí, ne na prázdný', () {
    final container = kontejner(const Nastaveni(vychoziPobocka: '12'));
    final controller = container.read(orderFilterProvider.notifier);

    controller.setBranch('13');
    expect(container.read(orderFilterProvider).branchCode, '13');

    controller.reset();
    expect(container.read(orderFilterProvider).branchCode, '12');
  });
}
