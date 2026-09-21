import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/auth/data/placeholder_auth_repository.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:renoworkshop/src/features/auth/presentation/controllers/stav_serveru.dart';
import 'package:renoworkshop/src/features/auth/presentation/screens/login_screen.dart';
import 'package:renoworkshop/src/core/theme/app_theme.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';

import '../helpers/fake_service_order_data_source.dart';

/// Řádek pod přihlášením dřív tvrdil „FIREMNÍ SÍŤ · ONLINE · V1.0.0",
/// i když server neodpovídal. Teď se ptá služby.
void main() {
  late FakeServiceOrderDataSource zdroj;

  Future<void> otevri(
    WidgetTester tester, {
    required bool serverOdpovida,
    bool pouzivaApi = true,
  }) async {
    zdroj = FakeServiceOrderDataSource([buildOrderDto()])
      ..serverOdpovida = serverOdpovida;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          authRepositoryProvider.overrideWithValue(
            PlaceholderAuthRepository(
              ssoDelay: Duration.zero,
              biometricDelay: Duration.zero,
            ),
          ),
          // Verze se v testu nečte ze zařízení.
          verzeAplikaceProvider.overrideWith((ref) async => '1.2.0 (73)'),
          pouzivaApiProvider.overrideWithValue(pouzivaApi),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('když služba odpovídá, svítí ONLINE s verzí', (tester) async {
    await otevri(tester, serverOdpovida: true);

    expect(find.text('ONLINE · 1.2.0 (73)'), findsOneWidget);
  });

  testWidgets('mimo firemní síť je vidět, že server nejede', (tester) async {
    await otevri(tester, serverOdpovida: false);

    expect(find.text('SERVER NEDOSTUPNÝ · 1.2.0 (73)'), findsOneWidget);
    expect(find.textContaining('ONLINE'), findsNothing);
  });

  testWidgets('build na ukázkových datech to přizná', (tester) async {
    await otevri(tester, serverOdpovida: true, pouzivaApi: false);

    expect(find.text('UKÁZKOVÁ DATA · 1.2.0 (73)'), findsOneWidget);
  });
}
