import 'dart:async';

import '../../domain/entities/order_status.dart';
import '../../domain/entities/service_order.dart';
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
  Future<ServiceOrder> updateStatus(String orderId, OrderStatus status) {
    return _mutate(
      orderId,
      () => _dataSource.updateStatus(orderId, status.apiValue),
    );
  }

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
