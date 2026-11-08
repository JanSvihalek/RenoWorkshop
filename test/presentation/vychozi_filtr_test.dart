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

    expect(filter.departmentCodes, isEmpty);
    expect(filter.isActive, isFalse);
  });

  test('výchozí útvar se propíše do filtru', () {
    final filter = kontejner(
      const Nastaveni(vychoziUtvary: ['12100', '13215']),
    ).read(orderFilterProvider);

    expect(filter.departmentCodes, {'12100', '13215'});
  });

  test('změna nastavení překreslí i právě otevřený seznam', () {
    final container = kontejner(const Nastaveni());

    expect(container.read(orderFilterProvider).departmentCodes, isEmpty);
    container.read(nastaveniProvider.notifier).zmenVychoziUtvary(['13215']);

    expect(container.read(orderFilterProvider).departmentCodes, {'13215'});
  });

  test('zrušení filtrů vrací na výchozí, ne na prázdný', () {
    final container = kontejner(const Nastaveni(vychoziUtvary: ['12100']));
    final controller = container.read(orderFilterProvider.notifier);

    controller.setDepartments({'13215'});
    expect(container.read(orderFilterProvider).departmentCodes, {'13215'});

    controller.reset();
    expect(container.read(orderFilterProvider).departmentCodes, {'12100'});
  });

  test('výchozí zodpovědná osoba se propíše do filtru', () {
    final filter = kontejner(
      const Nastaveni(
        vychoziUtvary: ['12100'],
        vychoziZodpovedni: ['Eva Malá'],
      ),
    ).read(orderFilterProvider);

    expect(filter.departmentCodes, {'12100'});
    expect(filter.mechanicNames, {'Eva Malá'});
  });

  test('výchozí pořadač se propíše do filtru', () {
    final filter = kontejner(
      const Nastaveni(vychoziPoradace: ['10026']),
    ).read(orderFilterProvider);

    expect(filter.poradacKody, {'10026'});
  });

  test('zrušení výchozího filtru v nastavení shodí útvar i osobu', () {
    final container = kontejner(
      const Nastaveni(
        vychoziUtvary: ['12100'],
        vychoziPoradace: ['10026'],
        vychoziZodpovedni: ['Eva Malá'],
      ),
    );

    container.read(nastaveniProvider.notifier).zrusVychoziFiltr();

    final nastaveni = container.read(nastaveniProvider);
    expect(nastaveni.vychoziUtvary, isEmpty);
    expect(nastaveni.vychoziZodpovedni, isEmpty);
    expect(nastaveni.vychoziPoradace, isEmpty);
    expect(nastaveni.maVychoziFiltr, isFalse);
  });

  test('druhé zrušení filtrů shodí i výchozí, ať tlačítko nezůstane mrtvé', () {
    // Technik s výchozím filtrem na sebe, který dnes nemá žádnou zakázku:
    // seznam je prázdný a „Zrušit filtry" ho nesmí vracet na tentýž.
    final container = kontejner(
      const Nastaveni(vychoziZodpovedni: ['Eva Malá']),
    );
    final controller = container.read(orderFilterProvider.notifier);

    controller.reset();
    expect(container.read(orderFilterProvider).mechanicNames, isEmpty);
    expect(container.read(orderFilterProvider).isActive, isFalse);
  });

  test('zrušení s jiným než výchozím filtrem vrací nejdřív na výchozí', () {
    final container = kontejner(
      const Nastaveni(vychoziZodpovedni: ['Eva Malá']),
    );
    final controller = container.read(orderFilterProvider.notifier);

    controller.setMechanici({'Jan Dvořák'});
    controller.reset();
    expect(container.read(orderFilterProvider).mechanicNames, {'Eva Malá'});

    controller.reset();
    expect(container.read(orderFilterProvider).mechanicNames, isEmpty);
  });

  test('výběr pobočky odebere útvary jiných poboček', () {
    final container = kontejner(const Nastaveni());
    final controller = container.read(orderFilterProvider.notifier);

    controller.setDepartments({'11215', '12215'});
    controller.setBranches({'1'});
    expect(container.read(orderFilterProvider).departmentCodes, {'11215'});
    controller.setBranches({});
    expect(container.read(orderFilterProvider).departmentCodes, {'11215'});
  });
}
