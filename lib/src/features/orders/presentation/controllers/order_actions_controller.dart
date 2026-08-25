import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/repositories/service_order_repository.dart';
import 'orders_providers.dart';

final orderActionsProvider =
    NotifierProvider<OrderActionsController, AsyncValue<void>>(
      OrderActionsController.new,
    );

/// Zápisové operace nad zakázkou (posun stavu, poznámka, úkony).
///
/// Stav controlleru je průběh poslední akce - UI podle něj blokuje CTA
/// a zobrazuje chybu. V produkci sem přibude optimistic update a offline
/// fronta; rozhraní vůči UI zůstane stejné.
class OrderActionsController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  ServiceOrderRepository get _repository =>
      ref.read(serviceOrderRepositoryProvider);

  /// Posun zakázky o jeden krok ve stavovém poli.
  /// Vrací nový stav, nebo `null` když je zakázka uzavřená / akce selhala.
  Future<OrderStatus?> advanceStatus(ServiceOrder order) async {
    final next = order.status.next;
    if (next == null) return null;

    state = const AsyncLoading();
    try {
      await _repository.updateStatus(order.id, next);
      state = const AsyncData(null);
      return next;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return null;
    }
  }

  Future<bool> addNote({required String orderId, required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final author = ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna';
    state = const AsyncLoading();
    try {
      await _repository.addNote(
        orderId: orderId,
        text: trimmed,
        author: author,
      );
      state = const AsyncData(null);
      return true;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return false;
    }
  }

  Future<void> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.setWorkItemDone(
        orderId: orderId,
        workItemId: workItemId,
        isDone: isDone,
      );
      state = const AsyncData(null);
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
    }
  }
}
