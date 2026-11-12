import '../../domain/entities/plan_klempirny.dart';
import 'dart:async';

import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/zpracovatel.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../datasources/service_order_data_source.dart';
import '../dtos/service_order_dto.dart';

/// Implementace [ServiceOrderRepository] nad libovolným
/// [ServiceOrderDataSource] - dnes mock, zítra REST.
///
/// Repository drží poslední známý stav dílny a po každé mutaci ho pošle
/// do streamu. Až přijde push z backendu, stačí do stejného streamu emitovat
/// data ze socketu - UI se nemění.
class ServiceOrderRepositoryImpl implements ServiceOrderRepository {
  ServiceOrderRepositoryImpl(this._dataSource);

  final ServiceOrderDataSource _dataSource;

  final StreamController<List<ServiceOrder>> _controller =
      StreamController<List<ServiceOrder>>.broadcast();

  List<ServiceOrder>? _cache;
  Future<List<ServiceOrder>>? _inFlight;

  @override
  Stream<List<ServiceOrder>> watchOrders() async* {
    yield await getOrders();
    yield* _controller.stream;
  }

  @override
  Future<List<ServiceOrder>> getOrders() async {
    // Souběžné požadavky (seznam + detail při cold startu) sdílí jedno načtení.
    final pending = _inFlight;
    if (pending != null) return pending;

    final future = _load();
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<List<ServiceOrder>> _load() async {
    try {
      final dtos = await _dataSource.fetchOrders();
      final orders = dtos.map((dto) => dto.toDomain()).toList();
      _cache = orders;
      return orders;
    } on ServiceOrderException {
      rethrow;
    } catch (error) {
      throw ServiceOrderException('Zakázky se nepodařilo načíst: $error');
    }
  }

  @override
  Future<List<ServiceOrder>> searchArchive(String query) async {
    try {
      final dtos = await _dataSource.searchOrders(query);
      return dtos.map((dto) => dto.toDomain()).toList();
    } on ServiceOrderException {
      rethrow;
    } catch (error) {
      throw ServiceOrderException('Hledání se nezdařilo: $error');
    }
  }

  @override
  Future<ServiceOrder> getOrder(String orderId) async {
    for (final order in _cache ?? const <ServiceOrder>[]) {
      if (order.id == orderId) return order;
    }

    final dto = await _dataSource.fetchOrder(orderId);
    if (dto == null) throw ServiceOrderNotFoundException(orderId);
    return dto.toDomain();
  }

  @override
  Future<ServiceOrder> pridejStav(
    String orderId, {
    String? kod,
    String? nazev,
    String? poznamka,
    String? misto,
    String? zavadaId,
    String? ukonId,
  }) {
    return _mutate(
      orderId,
      () => _dataSource.pridejStav(
        orderId,
        kod: kod,
        nazev: nazev,
        poznamka: poznamka,
        misto: misto,
        zavadaId: zavadaId,
        ukonId: ukonId,
      ),
    );
  }

  @override
  Future<ServiceOrder> ulozPredmetOpravy(String orderId, String text) {
    return _mutate(orderId, () => _dataSource.ulozPredmetOpravy(orderId, text));
  }

  @override
  Future<ServiceOrder> pridejRucniUkon(
    String orderId, {
    required String nazev,
    String? poznamka,
  }) {
    return _mutate(
      orderId,
      () => _dataSource.pridejRucniUkon(
        orderId,
        nazev: nazev,
        poznamka: poznamka,
      ),
    );
  }

  @override
  Future<ServiceOrder> smazRucniUkon(String orderId, String ukonId) {
    return _mutate(orderId, () => _dataSource.smazRucniUkon(orderId, ukonId));
  }

  @override
  Future<ServiceOrder> dokonciStav(String orderId, String zaznamId) {
    return _mutate(orderId, () => _dataSource.dokonciStav(orderId, zaznamId));
  }

  @override
  Future<ServiceOrder> zrusStav(String orderId, String zaznamId) {
    return _mutate(orderId, () => _dataSource.zrusStav(orderId, zaznamId));
  }

  @override
  Future<ServiceOrder> upravStav(
    String orderId,
    String zaznamId, {
    String? kod,
    String? nazev,
    String? poznamka,
  }) {
    return _mutate(
      orderId,
      () => _dataSource.upravStav(
        orderId,
        zaznamId,
        kod: kod,
        nazev: nazev,
        poznamka: poznamka,
      ),
    );
  }

  @override
  Future<NabidkaZpracovatelu> nabidkaZpracovatelu(
    String orderId, {
    bool vsichni = false,
  }) => _dataSource.nabidkaZpracovatelu(orderId, vsichni: vsichni);

  @override
  Future<ServiceOrder> nastavZpracovatele(String orderId, int? zamestnanecId) {
    return _mutate(
      orderId,
      () => _dataSource.nastavZpracovatele(orderId, zamestnanecId),
    );
  }

  @override
  Future<ServiceOrder> prevezmiZakazku(String orderId) {
    return _mutate(orderId, () => _dataSource.prevezmiZakazku(orderId));
  }

  @override
  Future<ServiceOrder> priradObalku(
    String orderId,
    String kod, {
    bool prepsat = false,
  }) {
    return _mutate(
      orderId,
      () => _dataSource.priradObalku(orderId, kod, prepsat: prepsat),
    );
  }

  @override
  Future<ServiceOrder> uvolniObalku(String orderId) {
    return _mutate(orderId, () => _dataSource.uvolniObalku(orderId));
  }

  @override
  Future<ServiceOrder> pridejUkonPlanu(String orderId, VstupUkonu ukon) {
    return _mutate(orderId, () => _dataSource.pridejUkonPlanu(orderId, ukon));
  }

  @override
  Future<ServiceOrder> upravUkonPlanu(
    String orderId,
    int ukonId,
    VstupUkonu ukon,
  ) {
    return _mutate(
      orderId,
      () => _dataSource.upravUkonPlanu(orderId, ukonId, ukon),
    );
  }

  @override
  Future<ServiceOrder> zrusUkonPlanu(String orderId, int ukonId) {
    return _mutate(orderId, () => _dataSource.zrusUkonPlanu(orderId, ukonId));
  }

  @override
  Future<List<NabidkaStavu>> nabidkaStavu() => _dataSource.nabidkaStavu();

  @override
  Future<ServiceOrder> addNote({
    required String orderId,
    required String text,
    required String author,
  }) {
    return _mutate(
      orderId,
      () => _dataSource.addNote(orderId: orderId, text: text, author: author),
    );
  }

  @override
  Future<ServiceOrder> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  }) {
    return _mutate(
      orderId,
      () => _dataSource.setWorkItemDone(
        orderId: orderId,
        workItemId: workItemId,
        isDone: isDone,
      ),
    );
  }

  /// Provede mutaci, promítne výsledek do cache a pošle nový seznam do streamu.
  Future<ServiceOrder> _mutate(
    String orderId,
    Future<ServiceOrderDto?> Function() operation,
  ) async {
    final dto = await operation();
    if (dto == null) throw ServiceOrderNotFoundException(orderId);

    final updated = dto.toDomain();
    final current = _cache ?? await getOrders();
    _cache = [
      for (final order in current)
        if (order.id == updated.id) updated else order,
    ];
    _emit();
    return updated;
  }

  void _emit() {
    final orders = _cache;
    if (orders != null && !_controller.isClosed) _controller.add(orders);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
