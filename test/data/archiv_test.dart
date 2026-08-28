import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';

import '../helpers/fake_service_order_data_source.dart';

void main() {
  test('hledání v archivu se ptá zdroje dat, ne načteného seznamu', () async {
    final zdroj = FakeServiceOrderDataSource([
      buildOrderDto(id: 'Z1212608412', licensePlate: '2BK9485'),
      buildOrderDto(id: 'Z1212401111', licensePlate: 'AA155HR'),
    ]);
    final container = ProviderContainer(
      overrides: [serviceOrderDataSourceProvider.overrideWithValue(zdroj)],
    );
    addTearDown(container.dispose);

    final nalezene = await container.read(archivProvider('AA155HR').future);

    expect(nalezene.map((z) => z.id), ['Z1212401111']);
    expect(zdroj.pocetHledani, 1);
  });

  test('krátký dotaz se na server vůbec neposílá', () async {
    final zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'Z1')]);
    final container = ProviderContainer(
      overrides: [serviceOrderDataSourceProvider.overrideWithValue(zdroj)],
    );
    addTearDown(container.dispose);

    final nalezene = await container.read(archivProvider('AB').future);

    expect(nalezene, isEmpty);
    expect(zdroj.pocetHledani, 0);
  });

  test('mezery se ignorují - SPZ z Heliosu je bez nich', () async {
    final zdroj = FakeServiceOrderDataSource([
      buildOrderDto(id: 'Z1212608412', licensePlate: '2BK9485'),
    ]);
    final container = ProviderContainer(
      overrides: [serviceOrderDataSourceProvider.overrideWithValue(zdroj)],
    );
    addTearDown(container.dispose);

    final nalezene = await container.read(archivProvider('2BK 9485').future);

    expect(nalezene, hasLength(1));
  });
}
