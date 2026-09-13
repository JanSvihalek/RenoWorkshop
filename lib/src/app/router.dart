import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/entities/auth_state.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../core/layout/rozlozeni.dart';
import '../core/widgets/workshop_scaffold.dart';
import '../features/orders/presentation/controllers/orders_providers.dart';
import '../features/orders/presentation/screens/archiv_screen.dart';
import '../features/orders/presentation/screens/order_detail_screen.dart';
import '../features/orders/presentation/screens/orders_list_screen.dart';
import '../features/orders/presentation/screens/rozdelene_zakazky_screen.dart';
import '../features/orders/presentation/screens/skener_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

/// Cesty appky na jednom místě - ať se v další fázi (deep linky z DMS,
/// notifikace) nemusí hledat po widgetech.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String orders = '/orders';
  static const String settings = '/settings';
  static const String archiv = '/archiv';
  static const String skener = '/skener';

  static String archivHledani(String dotaz) =>
      '$archiv?q=${Uri.encodeQueryComponent(dotaz)}';

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
        path: AppRoutes.skener,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => SkenerScreen(
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.orders),
            // Naskenovaný kód se vloží do hledání v seznamu, ne rovnou do
            // archivu: hledaný vůz obvykle stojí na dílně, takže je mezi
            // rozdělanými zakázkami. Když tam není, seznam sám nabídne
            // hledání v archivu.
            //
            // `go`, ne `pushReplacement`: skener se otevírá ze seznamu,
            // takže by jinak v zásobníku zůstaly dva seznamy pod sebou.
            onNalezeno: (kod) {
              ref.read(orderFilterProvider.notifier).setQuery(kod.hodnota);
              context.go(AppRoutes.orders);
            },
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.archiv,
        builder: (context, state) => ArchivScreen(
          dotaz: state.uri.queryParameters['q'] ?? '',
          onOpenOrder: (order) => context.push(AppRoutes.orderDetail(order.id)),
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.orders),
        ),
      ),
      // Záložky jsou ve společném rámu: přepnutí mění jen obsah, lišta
      // zůstává stát a každá záložka si drží svůj stav.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            WorkshopScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                // Na tabletu je seznam levým sloupcem vedle detailu, na
                // telefonu zůstává detail samostatnou obrazovkou nad ním.
                builder: (context, state) => context.jeTablet
                    ? RozdeleneZakazkyScreen(
                        onSearchArchive: (dotaz) =>
                            context.push(AppRoutes.archivHledani(dotaz)),
                        onScanCode: () => context.push(AppRoutes.skener),
                      )
                    : OrdersListScreen(
                        onOpenOrder: (order) =>
                            context.push(AppRoutes.orderDetail(order.id)),
                        onSearchArchive: (dotaz) =>
                            context.push(AppRoutes.archivHledani(dotaz)),
                        onScanCode: () => context.push(AppRoutes.skener),
                      ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Detail je mimo rám schválně: na telefonu překryje i lištu záložek,
      // protože zakázka není záložka, ale zanoření.
      GoRoute(
        path: '${AppRoutes.orders}/:orderId',
        builder: (context, state) => OrderDetailScreen(
          orderId: state.pathParameters['orderId']!,
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.orders),
        ),
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
