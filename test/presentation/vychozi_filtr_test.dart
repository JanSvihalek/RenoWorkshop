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

  test('výchozí zodpovědná osoba se propíše do filtru', () {
    final filter = kontejner(
      const Nastaveni(vychoziUtvar: '12100', vychoziZodpovida: 'Eva Malá'),
    ).read(orderFilterProvider);

    expect(filter.departmentCode, '12100');
    expect(filter.mechanicName, 'Eva Malá');
  });

  test('zrušení výchozího filtru v nastavení shodí útvar i osobu', () {
    final container = kontejner(
      const Nastaveni(vychoziUtvar: '12100', vychoziZodpovida: 'Eva Malá'),
    );

    container.read(nastaveniProvider.notifier).zrusVychoziFiltr();

    final nastaveni = container.read(nastaveniProvider);
    expect(nastaveni.vychoziUtvar, isNull);
    expect(nastaveni.vychoziZodpovida, isNull);
    expect(nastaveni.maVychoziFiltr, isFalse);
  });

  test('druhé zrušení filtrů shodí i výchozí, ať tlačítko nezůstane mrtvé', () {
    // Technik s výchozím filtrem na sebe, který dnes nemá žádnou zakázku:
    // seznam je prázdný a „Zrušit filtry" ho nesmí vracet na tentýž.
    final container = kontejner(const Nastaveni(vychoziZodpovida: 'Eva Malá'));
    final controller = container.read(orderFilterProvider.notifier);

    controller.reset();
    expect(container.read(orderFilterProvider).mechanicName, isNull);
    expect(container.read(orderFilterProvider).isActive, isFalse);
  });

  test('zrušení s jiným než výchozím filtrem vrací nejdřív na výchozí', () {
    final container = kontejner(const Nastaveni(vychoziZodpovida: 'Eva Malá'));
    final controller = container.read(orderFilterProvider.notifier);

    controller.setMechanic('Jan Dvořák');
    controller.reset();
    expect(container.read(orderFilterProvider).mechanicName, 'Eva Malá');

    controller.reset();
    expect(container.read(orderFilterProvider).mechanicName, isNull);
  });
}
