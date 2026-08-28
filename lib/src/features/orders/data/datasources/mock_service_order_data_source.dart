import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../dtos/service_order_dto.dart';
import 'service_order_data_source.dart';

/// Fáze 1: zakázky z lokálního JSONu, mutace jen v paměti.
///
/// Simuluje latenci sítě, aby UI muselo počítat s loading stavem stejně
/// jako u reálného API.
class MockServiceOrderDataSource implements ServiceOrderDataSource {
  MockServiceOrderDataSource({
    AssetBundle? bundle,
    this.assetPath = 'assets/mock/service_orders.json',
    this.latency = const Duration(milliseconds: 320),
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  /// Umělé zpoždění "sítě". V testech se nastavuje na [Duration.zero].
  final Duration latency;

  /// In-memory stav dílny. Přežije navigaci, ne restart appky.
  List<ServiceOrderDto>? _cache;

  Future<List<ServiceOrderDto>> _ensureLoaded() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final orders = (decoded['orders'] as List<dynamic>)
        .map((item) => ServiceOrderDto.fromJson(item as Map<String, dynamic>))
        .toList();
    return _cache = orders;
  }

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  int _indexOf(List<ServiceOrderDto> orders, String orderId) =>
      orders.indexWhere((order) => order.id == orderId);

  @override
  Future<List<ServiceOrderDto>> fetchOrders() async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    return List.unmodifiable(orders);
  }

  @override
  Future<ServiceOrderDto?> fetchOrder(String orderId) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    return index == -1 ? null : orders[index];
  }

  @override
  Future<List<ServiceOrderDto>> searchOrders(String query) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();

    final hledane = query.trim().toUpperCase().replaceAll(' ', '');
    if (hledane.isEmpty) return const [];

    // Mock nemá archiv uzavřených zakázek, hledá se tedy v tom, co je.
    // Proti API je rozdíl jen v rozsahu dat, ne v chování.
    return orders.where((dto) {
      final prohledavane = [
        dto.id,
        dto.licensePlate,
        dto.vin,
        dto.customerName,
      ].join(' ').toUpperCase().replaceAll(' ', '');
      return prohledavane.contains(hledane);
    }).toList();
  }

  @override
  Future<ServiceOrderDto?> updateStatus(
    String orderId,
    String statusApiValue,
  ) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final updated = orders[index].copyWith(status: statusApiValue);
    orders[index] = updated;
    return updated;
  }

  @override
  Future<ServiceOrderDto?> addNote({
    required String orderId,
    required String text,
    required String author,
  }) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final note = OrderNoteDto(
      id: 'N-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      author: author,
      createdAt: DateTime.now().toIso8601String(),
    );
    final updated = orders[index].copyWith(
      notes: [note, ...orders[index].notes],
    );
    orders[index] = updated;
    return updated;
  }

  @override
  Future<ServiceOrderDto?> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  }) async {
    final orders = await _ensureLoaded();
    await _simulateLatency();
    final index = _indexOf(orders, orderId);
    if (index == -1) return null;

    final updated = orders[index].copyWith(
      workItems: orders[index].workItems
          .map(
            (item) =>
                item.id == workItemId ? item.copyWith(isDone: isDone) : item,
          )
          .toList(),
    );
    orders[index] = updated;
    return updated;
  }
}
