import '../../domain/entities/dilensky_stav.dart';
import '../dtos/service_order_dto.dart';

/// Zdroj dat o zakázkách - jediné místo, které se v další fázi vymění
/// za implementaci nad REST API interního servisního systému (DMS).
///
/// Implementace ve fázi 1: [MockServiceOrderDataSource] (lokální JSON).
/// Plánovaná implementace fáze 2: `RestServiceOrderDataSource` (Dio + auth
/// interceptor s tokenem z Entra ID).
abstract interface class ServiceOrderDataSource {
  /// Žije služba a je na ni z tohohle zařízení vidět?
  ///
  /// `GET /health` - jediný endpoint bez přihlášení. Používá to přihlašovací
  /// obrazovka: technik v hale hned vidí, jestli je na firemní síti, místo
  /// aby se to dozvěděl až chybou po přihlášení.
  Future<bool> serverBezi();

  Future<List<ServiceOrderDto>> fetchOrders();

  Future<ServiceOrderDto?> fetchOrder(String orderId);

  /// Hledání napříč archivem, tedy i mezi uzavřenými zakázkami.
  ///
  /// `GET /orders/search?q=...` - na rozdíl od [fetchOrders] se neomezuje
  /// na dílnu a poslední měsíce. Slouží k dohledání staré zakázky podle
  /// SPZ nebo VINu, typicky kvůli fotodokumentaci.
  Future<List<ServiceOrderDto>> searchOrders(String query);

  /// PATCH /orders/{id} { status }
  /// Přidá dílenský stav. Buď `kod` z číselníku, nebo vlastní `nazev`.
  Future<ServiceOrderDto?> pridejStav(
    String orderId, {
    String? kod,
    String? nazev,
    String? poznamka,
  });

  /// `PUT /orders/{id}/repair-subject` - přepíše předmět opravy, prázdný
  /// text ho smaže.
  Future<ServiceOrderDto?> ulozPredmetOpravy(String orderId, String text);

  /// Smaže záznam z historie stavů.
  Future<ServiceOrderDto?> smazStav(String orderId, String zaznamId);

  /// `POST /sync` - okamžité dotažení zakázek z Heliosu. Server ho pustí
  /// nejvýš jednou za minutu pro celou dílnu; jinak chyba s počtem vteřin.
  Future<void> synchronizuj();

  /// Nabídka stavů z číselníku na serveru.
  Future<List<NabidkaStavu>> nabidkaStavu();

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
