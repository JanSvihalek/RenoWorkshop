import '../dtos/service_order_dto.dart';

/// Zdroj dat o zakázkách - jediné místo, které se v další fázi vymění
/// za implementaci nad REST API interního servisního systému (DMS).
///
/// Implementace ve fázi 1: [MockServiceOrderDataSource] (lokální JSON).
/// Plánovaná implementace fáze 2: `RestServiceOrderDataSource` (Dio + auth
/// interceptor s tokenem z Entra ID).
abstract interface class ServiceOrderDataSource {
  Future<List<ServiceOrderDto>> fetchOrders();

  Future<ServiceOrderDto?> fetchOrder(String orderId);

  /// Hledání napříč archivem, tedy i mezi uzavřenými zakázkami.
  ///
  /// `GET /orders/search?q=...` - na rozdíl od [fetchOrders] se neomezuje
  /// na dílnu a poslední měsíce. Slouží k dohledání staré zakázky podle
  /// SPZ nebo VINu, typicky kvůli fotodokumentaci.
  Future<List<ServiceOrderDto>> searchOrders(String query);

  /// PATCH /orders/{id} { status }
  Future<ServiceOrderDto?> updateStatus(String orderId, String statusApiValue);

  /// POST /orders/{id}/notes
  Future<ServiceOrderDto?> addNote({
    required String orderId,
    required String text,
    required String author,
  });

  /// PATCH /orders/{id}/work-items/{workItemId} { isDone }
  Future<ServiceOrderDto?> setWorkItemDone({
    required String orderId,
    required String workItemId,
    required bool isDone,
  });
}
