import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/entities/auth_state.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/orders/presentation/screens/order_detail_screen.dart';
import '../features/orders/presentation/screens/orders_list_screen.dart';

/// Cesty appky na jednom místě - ať se v další fázi (deep linky z DMS,
/// notifikace) nemusí hledat po widgetech.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String orders = '/orders';

  static String orderDetail(String orderId) => '$orders/$orderId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.orders,
    refreshListenable: refresh,
    // Auth guard: bez přihlášení se do zakázek nedostaneme.
    // Ve fázi 2 tady přibude kontrola rolí z Entra ID.
    redirect: (context, state) {
      final isSignedIn = ref.read(authControllerProvider) is AuthSignedIn;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      if (!isSignedIn) return isOnLogin ? null : AppRoutes.login;
      if (isOnLogin) return AppRoutes.orders;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => OrdersListScreen(
          onOpenOrder: (order) =>
              context.push(AppRoutes.orderDetail(order.id)),
        ),
        routes: [
          GoRoute(
            path: ':orderId',
            builder: (context, state) => OrderDetailScreen(
              orderId: state.pathParameters['orderId']!,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.orders),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Přemostění Riverpodu a go_routeru - při změně přihlášení přepočítá redirect.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
