import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/entities/auth_state.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../core/layout/rozlozeni.dart';
import '../core/widgets/workshop_scaffold.dart';
import '../features/orders/presentation/controllers/orders_providers.dart';
import '../features/orders/presentation/screens/order_detail_screen.dart';
import '../features/orders/presentation/screens/orders_list_screen.dart';
import '../features/orders/presentation/screens/rozdelene_zakazky_screen.dart';
import '../features/orders/presentation/screens/skener_screen.dart';
import '../features/fotodokumentace/presentation/screens/fotodokumentace_screen.dart';
import '../features/prijem/presentation/screens/prijem_zakazky_screen.dart';
import '../features/settings/domain/entities/nastaveni.dart';
import '../features/settings/presentation/controllers/nastaveni_controller.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/vozidla/presentation/controllers/vozidla_providers.dart';
import '../features/vozidla/presentation/screens/karta_vozidla_screen.dart';
import '../features/vozidla/presentation/screens/vozidlo_screen.dart';
import 'log_udalosti_provider.dart';
import '../core/navigace/pozadavek_skeneru.dart';
import '../core/widgets/workshop_bottom_nav.dart';

/// Cesty appky na jednom místě - ať se v další fázi (deep linky z DMS,
/// notifikace) nemusí hledat po widgetech.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String orders = '/orders';
  static const String settings = '/settings';
  static const String skener = '/skener';

  /// Záložka Vozidlo - hledání vozu i zakázky k příjmu.
  static const String vozidlo = '/vozidlo';
  static const String vozidla = '/vozidla';
  static const String prijem = '/prijem';

  static String prijemZakazky(String orderId) =>
      '$prijem/${Uri.encodeComponent(orderId)}';

  /// Skener, jehož výsledek jde do záložky Vozidlo, ne do seznamu zakázek.
  static const String skenerVozidla = '$skener?cil=vozidlo';

  /// `naskenovano` jen do popisku na kartě - vůz se našel podle SPZ
  /// z fotoaparátu.
  static String kartaVozidla(int id, {bool naskenovano = false}) =>
      naskenovano ? '$vozidla/$id?sken=1' : '$vozidla/$id';

  static String orderDetail(String orderId) => '$orders/$orderId';

  static String fotodokumentace(String orderId) =>
      '$orders/${Uri.encodeComponent(orderId)}/fotky';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  // Úvodní záložka podle nastavení - čte se pokaždé znovu, ať po změně
  // v nastavení platí už pro příští přihlášení.
  String uvodni() => switch (ref.read(nastaveniProvider).uvodniZalozka) {
    UvodniZalozka.zakazky => AppRoutes.orders,
    UvodniZalozka.vozidlo => AppRoutes.vozidlo,
  };

  final router = GoRouter(
    initialLocation: uvodni(),
    refreshListenable: refresh,
    // Auth guard: bez přihlášení se do zakázek nedostaneme.
    // Ve fázi 2 tady přibude kontrola rolí z Entra ID.
    redirect: (context, state) {
      final isSignedIn = ref.read(authControllerProvider) is AuthSignedIn;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      if (!isSignedIn) return isOnLogin ? null : AppRoutes.login;
      if (isOnLogin) return uvodni();
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
            // Ze záložky Vozidlo, kam se skener otevírá sám, musí jít rychle
            // přejít k psaní - skener se zavře a pole si vezme klávesnici.
            onRucne: state.uri.queryParameters['cil'] == 'vozidlo'
                ? () {
                    ref.read(zadatRucneProvider.notifier).state =
                        WorkshopTab.vozidlo;
                    context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.vozidlo);
                  }
                : null,
            // Naskenovaný kód se vloží do hledání v seznamu, ne rovnou do
            // archivu: hledaný vůz obvykle stojí na dílně, takže je mezi
            // rozdělanými zakázkami. Když tam není, seznam sám nabídne
            // hledání v archivu.
            //
            // `go`, ne `pushReplacement`: skener se otevírá ze seznamu,
            // takže by jinak v zásobníku zůstaly dva seznamy pod sebou.
            onNalezeno: (kod) {
              // Ze záložky Vozidlo: SPZ jde do hledání. Vůz na dílně ukáže
              // kartu příjmu, jediný vůz bez zakázky se otevře rovnou.
              if (state.uri.queryParameters['cil'] == 'vozidlo') {
                ref.read(dotazVozidlaProvider.notifier).state = kod.hodnota;
                ref.read(otevritJedineVozidloProvider.notifier).state = true;
                context.go(AppRoutes.vozidlo);
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
                // V tabulce je detail vždy přes celou obrazovku - vedle
                // deseti sloupců by se nevešel.
                builder: (context, state) => Consumer(
                  builder: (context, ref, _) {
                    final vTabulce =
                        ref.watch(nastaveniProvider).zobrazeniZakazek ==
                        ZobrazeniZakazek.tabulka;
                    return context.jeTablet && !vTabulce
                        ? RozdeleneZakazkyScreen(
                            onScanCode: () => context.push(AppRoutes.skener),
                            onFotodokumentace: (id) =>
                                context.push(AppRoutes.fotodokumentace(id)),
                            onPrijem: (id) =>
                                context.push(AppRoutes.prijemZakazky(id)),
                          )
                        : OrdersListScreen(
                            onOpenOrder: (order) =>
                                context.push(AppRoutes.orderDetail(order.id)),
                            onScanCode: () => context.push(AppRoutes.skener),
                          );
                  },
                ),
              ),
            ],
          ),
          // Pořadí větví musí sedět s WorkshopTab: zakázky, vozidlo,
          // nastavení.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.vozidlo,
                // Nalezený vůz se otevře přes celou obrazovku i na tabletu.
                builder: (context, state) => VozidloScreen(
                  onScan: () => context.push(AppRoutes.skenerVozidla),
                  onOpenZakazka: (zakazka) =>
                      context.push(AppRoutes.prijemZakazky(zakazka.id)),
                  onOpenDetail: (zakazka) =>
                      context.push(AppRoutes.orderDetail(zakazka.id)),
                  onOpenVozidlo: (vozidlo, naskenovano) => context.push(
                    AppRoutes.kartaVozidla(
                      vozidlo.id,
                      naskenovano: naskenovano,
                    ),
                  ),
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
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.vozidlo),
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
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => KartaVozidlaScreen(
            vozidloId: int.tryParse(state.pathParameters['vozidloId']!) ?? -1,
            naskenovano: state.uri.queryParameters['sken'] == '1',
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.vozidlo),
            onOpenOrder: (order) =>
                context.push(AppRoutes.orderDetail(order.id)),
            // Není to ten vůz: hledání pryč, zpět na záložku a znovu skener.
            onNeniToOno: () {
              ref.read(otevritJedineVozidloProvider.notifier).state = false;
              ref.read(dotazVozidlaProvider.notifier).state = '';
              final router = GoRouter.of(context);
              router.canPop() ? router.pop() : router.go(AppRoutes.vozidlo);
              router.push(AppRoutes.skenerVozidla);
            },
          ),
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

  // Každá změna obrazovky do logu událostí - z něj je pak vidět, jak se
  // technik k chybě dostal. Jen cesta, bez query (hledaný text).
  void zapisObrazovku() => ref
      .read(logUdalostiProvider)
      .obrazovka(router.routerDelegate.currentConfiguration.uri.path);
  router.routerDelegate.addListener(zapisObrazovku);
  ref.onDispose(() => router.routerDelegate.removeListener(zapisObrazovku));
  return router;
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
