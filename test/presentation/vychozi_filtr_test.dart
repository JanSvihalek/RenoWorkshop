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

    expect(filter.departmentCode, isNull);
    expect(filter.isActive, isFalse);
  });

  test('výchozí útvar se propíše do filtru', () {
    final filter = kontejner(
      const Nastaveni(vychoziUtvar: '12100'),
    ).read(orderFilterProvider);

    expect(filter.departmentCode, '12100');
  });

  test('změna nastavení překreslí i právě otevřený seznam', () {
    final container = kontejner(const Nastaveni());

    expect(container.read(orderFilterProvider).departmentCode, isNull);
    container.read(nastaveniProvider.notifier).zmenVychoziUtvar('13215');

    expect(container.read(orderFilterProvider).departmentCode, '13215');
  });

  test('zrušení filtrů vrací na výchozí, ne na prázdný', () {
    final container = kontejner(const Nastaveni(vychoziUtvar: '12100'));
    final controller = container.read(orderFilterProvider.notifier);

    controller.setDepartment('13215');
    expect(container.read(orderFilterProvider).departmentCode, '13215');

    controller.reset();
    expect(container.read(orderFilterProvider).departmentCode, '12100');
  });
}
