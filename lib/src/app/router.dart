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
import '../features/fotodokumentace/presentation/screens/fotodokumentace_screen.dart';
import '../features/prijem/presentation/controllers/prijem_providers.dart';
import '../features/prijem/presentation/screens/prijem_screen.dart';
import '../features/prijem/presentation/screens/prijem_zakazky_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/vozidla/presentation/controllers/vozidla_providers.dart';
import '../features/vozidla/presentation/screens/karta_vozidla_screen.dart';
import '../features/vozidla/presentation/screens/rozdelene_vyhledavani_screen.dart';
import '../features/vozidla/presentation/screens/vyhledavani_screen.dart';

/// Cesty appky na jednom místě - ať se v další fázi (deep linky z DMS,
/// notifikace) nemusí hledat po widgetech.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String orders = '/orders';
  static const String settings = '/settings';
  static const String archiv = '/archiv';
  static const String skener = '/skener';
  static const String vyhledavani = '/vyhledavani';
  static const String vozidla = '/vozidla';
  static const String prijem = '/prijem';

  /// Skener, jehož SPZ jde do hledání zakázky k příjmu.
  static const String skenerPrijmu = '$skener?cil=prijem';

  static String prijemZakazky(String orderId) =>
      '$prijem/${Uri.encodeComponent(orderId)}';

  /// Skener, jehož výsledek jde do vyhledání vozidla, ne do seznamu zakázek.
  static const String skenerVozidla = '$skener?cil=vozidla';

  static String kartaVozidla(int id) => '$vozidla/$id';

  static String archivHledani(String dotaz) =>
      '$archiv?q=${Uri.encodeQueryComponent(dotaz)}';

  static String orderDetail(String orderId) => '$orders/$orderId';

  static String fotodokumentace(String orderId) =>
      '$orders/${Uri.encodeComponent(orderId)}/fotky';
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
              // Z příjmu: SPZ jde do hledání zakázky a jediná nalezená
              // se rovnou otevře ke kontrole.
              if (state.uri.queryParameters['cil'] == 'prijem') {
                ref.read(dotazPrijmuProvider.notifier).state = kod.hodnota;
                ref.read(otevritJedinyPrijemProvider.notifier).state = true;
                context.go(AppRoutes.prijem);
                return;
              }
              // Ze záložky vozidel: SPZ jde do vyhledání vozidla a jediný
              // nalezený vůz se rovnou otevře.
              if (state.uri.queryParameters['cil'] == 'vozidla') {
                ref.read(dotazVozidlaProvider.notifier).state = kod.hodnota;
                ref.read(otevritJedineVozidloProvider.notifier).state = true;
                context.go(AppRoutes.vyhledavani);
                return;
              }
              // Jediná nalezená zakázka se otevře rovnou - u příjmu se
              // tak po naskenování SPZ jde přímo k detailu a fotkám.
              ref.read(otevritJedinouZakazkuProvider.notifier).state = true;
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
                        onFotodokumentace: (id) =>
                            context.push(AppRoutes.fotodokumentace(id)),
                        onPrijem: (id) =>
                            context.push(AppRoutes.prijemZakazky(id)),
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
          // Pořadí větví musí sedět s WorkshopTab: zakázky, příjem, vozidla,
          // nastavení.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.prijem,
                builder: (context, state) => PrijemScreen(
                  onScan: () => context.push(AppRoutes.skenerPrijmu),
                  onOpenZakazka: (zakazka) =>
                      context.push(AppRoutes.prijemZakazky(zakazka.id)),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.vyhledavani,
                builder: (context, state) => context.jeTablet
                    ? RozdeleneVyhledavaniScreen(
                        onScan: () => context.push(AppRoutes.skenerVozidla),
                        onOpenOrder: (order) =>
                            context.push(AppRoutes.orderDetail(order.id)),
                      )
                    : VyhledavaniScreen(
                        onScan: () => context.push(AppRoutes.skenerVozidla),
                        onOpenVozidlo: (vozidlo) =>
                            context.push(AppRoutes.kartaVozidla(vozidlo.id)),
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
      // Karta vozidla i detail zakázky jsou mimo rám schválně: na telefonu
      // překryjí i lištu záložek, protože nejsou záložka, ale zanoření.
      GoRoute(
        path: '${AppRoutes.prijem}/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return PrijemZakazkyScreen(
            orderId: orderId,
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.prijem),
            onFotodokumentace: () =>
                context.push(AppRoutes.fotodokumentace(orderId)),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.orders}/:orderId/fotky',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return FotodokumentaceScreen(
            orderId: orderId,
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.orderDetail(orderId)),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.vozidla}/:vozidloId',
        builder: (context, state) => KartaVozidlaScreen(
          vozidloId: int.tryParse(state.pathParameters['vozidloId']!) ?? -1,
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.vyhledavani),
          onOpenOrder: (order) => context.push(AppRoutes.orderDetail(order.id)),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.orders}/:orderId',
        builder: (context, state) => OrderDetailScreen(
          orderId: state.pathParameters['orderId']!,
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.orders),
          onFotodokumentace: (id) =>
              context.push(AppRoutes.fotodokumentace(id)),
          onPrijem: (id) => context.push(AppRoutes.prijemZakazky(id)),
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
