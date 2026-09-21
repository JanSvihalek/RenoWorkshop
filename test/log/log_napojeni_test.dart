import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/app/log_udalosti_provider.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/domain/entities/auth_state.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/order_actions_controller.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Přihlášení a práce s postupem a poznámkami končí v logu událostí -
/// v posloupnosti kroků uživatele musí být vidět.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
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
      ],
    );
    addTearDown(container.dispose);
  });

  List<String> nazvy() => [
    for (final u in container.read(logUdalostiProvider).fronta) u.nazev,
  ];

  test('přihlášení a odhlášení', () async {
    await container
        .read(authControllerProvider.notifier)
        .signIn(SignInMethod.microsoftSso);
    await container.read(authControllerProvider.notifier).signOut();

    expect(nazvy(), ['prihlaseni', 'odhlaseni']);
  });

  test('stav a poznámka - kód stavu ano, text poznámky ne', () async {
    await container.read(ordersStreamProvider.future);
    final akce = container.read(orderActionsProvider.notifier);

    await akce.pridejStav('ZK-26-0001', kod: 'lakovna');
    await akce.addNote(orderId: 'ZK-26-0001', text: 'Volat až po 15:00');
    final zaznamId = container
        .read(orderByIdProvider('ZK-26-0001'))
        .requireValue!
        .historieStavu
        .first
        .id!;
    await akce.smazStav('ZK-26-0001', zaznamId);

    final log = container.read(logUdalostiProvider).fronta;
    expect(log.map((u) => u.nazev), [
      'stav_pridan',
      'poznamka_pridana',
      'stav_smazan',
    ]);
    expect(log.every((u) => u.zakazka == 'ZK-26-0001'), isTrue);
    expect(log[0].detail, 'lakovna');
    expect(log[1].detail, 'znaků 17');
    expect(
      log.map((u) => u.toJson().toString()).join(),
      isNot(contains('15:00')),
    );
  });
}
