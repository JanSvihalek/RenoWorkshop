import '../entities/order_status.dart';
import '../entities/service_order.dart';

/// Kontrakt datové vrstvy pro servisní zakázky.
///
/// UI a state management znají **jen tohle rozhraní**. Ve fázi 1 ho plní
/// `ServiceOrderRepositoryImpl` nad mock JSONem; v další fázi se vymění
/// datový zdroj za REST API (a případně websocket) bez zásahu do UI.
abstract interface class ServiceOrderRepository {
  /// Proud zakázek na dílně. Emituje znovu po každé mutaci.
  ///
  /// Stav dílny je sdílený mezi více uživateli - proto stream (dnes lokální
  /// broadcast, později polling nebo push z backendu).
  Stream<List<ServiceOrder>> watchOrders();

  /// Jednorázové načtení (pull-to-refresh, cold start).
  Future<List<ServiceOrder>> getOrders();

  /// Detail jedné zakázky. Vyhodí [ServiceOrderNotFoundException].
  Future<ServiceOrder> getOrder(String orderId);

  /// Nastaví stav zakázky (posun na dílně).
  Future<ServiceOrder> updateStatus(String orderId, OrderStatus status);

  /// Přidá poznámku mechanika / poradce.
  Future<ServiceOrder> addNote({
    required String orderId,
    required String text,
    required String author,
  });

  /// Označí úkon jako provedený / plánovaný.
  Future<ServiceOrder> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  });

  /// Uvolní zdroje (stream controller, HTTP klient).
  void dispose();
}

/// Chyba datové vrstvy prezentovatelná uživateli.
class ServiceOrderException implements Exception {
  const ServiceOrderException(this.message);

  final String message;

  @override
  String toString() => 'ServiceOrderException: $message';
}

class ServiceOrderNotFoundException extends ServiceOrderException {
  const ServiceOrderNotFoundException(this.orderId)
    : super('Zakázka $orderId nebyla nalezena.');

  final String orderId;
}
