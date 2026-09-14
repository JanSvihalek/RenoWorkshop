import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/config/app_config.dart';
import '../../data/datasources/mock_service_order_data_source.dart';
import '../../data/datasources/rest_service_order_data_source.dart';
import '../../data/datasources/service_order_data_source.dart';
import '../../data/skener_kodu.dart';
import '../../data/repositories/service_order_repository_impl.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/order_filter.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/typ_zakazky.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../../../settings/domain/entities/nastaveni.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';

/// Zdroj dat: bez `API_BASE_URL` mock JSON, s ním reálné API.
/// Jediné místo, kde se to rozhoduje - zbytek appky rozdíl nepozná.
final serviceOrderDataSourceProvider = Provider<ServiceOrderDataSource>((ref) {
  if (!AppConfig.pouzivaApi) return MockServiceOrderDataSource();

  final dataSource = RestServiceOrderDataSource(
    baseUrl: Uri.parse(AppConfig.apiBaseUrl),
    // Token se bere až při volání, ne při sestavení - Firebase ho sám
    // obnovuje a starý by po hodině přestal platit.
    tokenProvider: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  ref.onDispose(dataSource.dispose);
  return dataSource;
});

final serviceOrderRepositoryProvider = Provider<ServiceOrderRepository>((ref) {
  final repository = ServiceOrderRepositoryImpl(
    ref.watch(serviceOrderDataSourceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Všechny zakázky na dílně (sdílený stav, proto stream).
final ordersStreamProvider = StreamProvider<List<ServiceOrder>>(
  (ref) => ref.watch(serviceOrderRepositoryProvider).watchOrders(),
);

/// Útvary na dané pobočce. `null` jako kód pobočky vrací útvary všechny.
///
/// Parametrizované proto, že se ptají dvě různá místa: filtrovací panel na
/// právě vybranou pobočku a nastavení na tu, která se teprve vybírá jako
/// výchozí.
final departmentsForBranchProvider = Provider.family<List<Department>, String?>(
  (ref, branchCode) {
    final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
    final unikatni = <String, Department>{};
    for (final order in orders) {
      if (branchCode != null && order.branch?.code != branchCode) continue;
      final department = order.department;
      if (department != null) unikatni[department.code] = department;
    }
    // Řadí se podle kódu, protože se podle kódu i zobrazují - útvary
    // jedné pobočky tak jdou za sebou v číselném pořadí.
    final seznam = unikatni.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return seznam;
  },
);

/// Útvary v rámci právě vybrané pobočky - jemnější filtr ve filtrovacím
/// panelu.
final availableDepartmentsProvider = Provider<List<Department>>((ref) {
  final branchCode = ref.watch(orderFilterProvider).branchCode;
  return ref.watch(departmentsForBranchProvider(branchCode));
});

/// Typy zakázek vyskytující se v načtených datech. Číselník je v Heliosu
/// a rozšiřuje se tam, proto se nabídka skládá z dat, ne z pevného výčtu.
final availableOrderTypesProvider = Provider<List<TypZakazky>>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  final unikatni = <String, TypZakazky>{};
  for (final order in orders) {
    final typ = order.typZakazky;
    if (typ != null) unikatni[typ.kod] = typ;
  }
  final seznam = unikatni.values.toList()
    ..sort((a, b) => a.nazev.compareTo(b.nazev));
  return seznam;
});

/// Nabídka dílenských stavů ze serveru.
///
/// Číselník žije v databázi, takže nový stav se v aplikaci objeví sám -
/// bez nové verze v telefonech. Když se nabídku nepodaří načíst, appka
/// dál funguje: stav se dá zapsat ručně.
final nabidkaStavuProvider = FutureProvider<List<NabidkaStavu>>((ref) {
  return ref.watch(serviceOrderRepositoryProvider).nabidkaStavu();
});

/// Stavy, které se vyskytují v načtených zakázkách - podle nich se
/// filtruje. Skládají se z dat, ne z číselníku: filtrovat podle stavu,
/// který na dílně nikdo nemá, nemá smysl.
final pouziteStavyProvider = Provider<List<DilenskyStav>>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  final unikatni = <String, DilenskyStav>{};
  for (final order in orders) {
    final stav = order.stav;
    if (stav?.kod != null) unikatni[stav!.kod!] = stav;
  }
  final seznam = unikatni.values.toList()
    ..sort((a, b) => a.nazev.compareTo(b.nazev));
  return seznam;
});

/// Čtení VINu a SPZ fotoaparátem. Vlastní provider, aby šel v testech
/// nahradit bez zapojení kamery.
final skenerProvider = Provider<SkenerKodu>((ref) {
  final skener = SkenerKodu();
  ref.onDispose(skener.dispose);
  return skener;
});

/// Výsledek hledání v archivu. `family` podle hledaného textu, takže se
/// stejný dotaz nepouští dvakrát a při návratu na obrazovku je výsledek
/// hned k dispozici.
final archivProvider = FutureProvider.family<List<ServiceOrder>, String>((
  ref,
  dotaz,
) async {
  final ocisteny = dotaz.trim();
  if (ocisteny.length < 3) return const [];
  return ref.watch(serviceOrderRepositoryProvider).searchArchive(ocisteny);
});

/// Aktivní filtry seznamu.
final orderFilterProvider =
    NotifierProvider<OrderFilterController, OrderFilter>(
      OrderFilterController.new,
    );

/// Zakázky po aplikaci filtrů a řazení.
final filteredOrdersProvider = Provider<AsyncValue<List<ServiceOrder>>>((ref) {
  final filter = ref.watch(orderFilterProvider);
  return ref.watch(ordersStreamProvider).whenData(filter.apply);
});

/// Detail jedné zakázky. Čte ze stejného streamu jako seznam, takže posun
/// stavu v detailu se hned projeví i v seznamu.
final orderByIdProvider = Provider.family<AsyncValue<ServiceOrder?>, String>((
  ref,
  orderId,
) {
  return ref
      .watch(ordersStreamProvider)
      .when(
        data: (orders) {
          for (final order in orders) {
            if (order.id == orderId) return AsyncData(order);
          }
          // Na dílně není - ukončená zakázka z archivu nebo z karty vozidla.
          // Dřív tu detail skončil hláškou "nebyla nalezena", přestože
          // server zakázku má.
          return ref.watch(zakazkaMimoDilnuProvider(orderId));
        },
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
      );
});

/// Zakázka, která není v seznamu dílny, načtená přímo ze serveru.
///
/// Po úpravě (přidání stavu, poznámka) ji [OrderActionsController]
/// zneplatní, ať se načte znovu - seznam dílny ji neobsahuje, takže by
/// se změna jinak do detailu nepropsala.
final zakazkaMimoDilnuProvider = FutureProvider.autoDispose
    .family<ServiceOrder?, String>((ref, orderId) async {
      try {
        return await ref
            .watch(serviceOrderRepositoryProvider)
            .getOrder(orderId);
      } on ServiceOrderNotFoundException {
        return null;
      }
    });

/// Mechanici, kterým je aktuálně přiřazená aspoň jedna zakázka (filtr).
final mechanicsProvider = Provider<List<String>>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  final names = <String>{
    for (final order in orders)
      if (order.mechanicName != null) order.mechanicName!,
  }.toList()..sort();
  return names;
});

class OrderFilterController extends Notifier<OrderFilter> {
  /// Seznam se otevře rovnou na pobočce, kterou má mechanik v nastavení.
  /// Většina lidí pracuje pořád na jedné a přepínat ji po každém spuštění
  /// je otrava; kdo chce vidět všechno, filtr shodí jedním klepnutím.
  @override
  OrderFilter build() => _vychozi(ref.watch(nastaveniProvider));

  static OrderFilter _vychozi(Nastaveni nastaveni) => OrderFilter(
    departmentCode: nastaveni.vychoziUtvar,
    mechanicName: nastaveni.vychoziZodpovida,
  );

  void setBranch(String? branchCode) => state = branchCode == null
      ? state.copyWith(clearBranch: true, clearDepartment: true)
      : state.copyWith(branchCode: branchCode, clearDepartment: true);

  void setTypZakazky(String? kod) => state = kod == null
      ? state.copyWith(clearTypZakazky: true)
      : state.copyWith(typZakazkyKod: kod);

  void setDepartment(String? departmentCode) => state = departmentCode == null
      ? state.copyWith(clearDepartment: true)
      : state.copyWith(departmentCode: departmentCode);

  void setStatus(String? statusCode) => state = statusCode == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(statusCode: statusCode);

  void setMechanic(String? mechanicName) => state = mechanicName == null
      ? state.copyWith(clearMechanic: true)
      : state.copyWith(mechanicName: mechanicName);

  void setQuery(String query) => state = state.copyWith(query: query);

  void setSort(OrderSort sort) => state = state.copyWith(sort: sort);

  /// Vrací na výchozí filtr z nastavení, ne na prázdný - jinak by
  /// „zrušit filtry" znamenalo něco jiného než otevření appky.
  ///
  /// Když už seznam na výchozím filtru stojí, shodí se i ten. Jinak by
  /// tlačítko v prázdném seznamu nedělalo nic: technik s výchozím filtrem
  /// na sebe, který zrovna nemá žádnou zakázku, by zůstal u prázdné
  /// obrazovky a „Zrušit filtry" by ho vracelo na ni.
  void reset() {
    final vychozi = _vychozi(ref.read(nastaveniProvider));
    state = state == vychozi ? const OrderFilter() : vychozi;
  }
}

/// Zakázka otevřená v pravém sloupci rozděleného zobrazení na tabletu.
///
/// Na telefonu se detail otevírá jako samostatná obrazovka a provider
/// nikdo nečte. Na tabletu se seznam kliknutím nepřekresluje celý -
/// drží si posun i rozepsané hledání, mění se jen sloupec vedle.
final vybranaZakazkaProvider = StateProvider<String?>((ref) => null);
