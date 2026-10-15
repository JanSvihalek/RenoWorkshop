import '../../domain/entities/plan_klempirny.dart';
import '../../domain/entities/obalka_klice.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/zpracovatel.dart';
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

    /// Kde vůz po tomhle kroku stojí. `null` = neměnit, prázdný text
    /// místo smaže.
    String? misto,
  });

  /// `PUT /orders/{id}/repair-subject` - přepíše předmět opravy, prázdný
  /// text ho smaže.
  Future<ServiceOrderDto?> ulozPredmetOpravy(String orderId, String text);

  /// Smaže záznam z historie stavů.
  Future<ServiceOrderDto?> smazStav(String orderId, String zaznamId);

  /// `GET /orders/{id}/assignees` - koho lze přiřadit jako zpracovatele.
  /// Lidé z útvaru zakázky, s [vsichni] všichni zaměstnanci.
  Future<NabidkaZpracovatelu> nabidkaZpracovatelu(
    String orderId, {
    bool vsichni = false,
  });

  /// `PUT /orders/{id}/assignee` - přiřadí zpracovatele, `null` zakázku
  /// uvolní.
  Future<ServiceOrderDto?> nastavZpracovatele(
    String orderId,
    int? zamestnanecId,
  );

  /// `PUT /orders/{id}/assignee/me` - zpracovatelem se stane přihlášený.
  /// Když ho server podle e-mailu v Heliosu nenajde, [ServiceOrderException]
  /// s hláškou pro uživatele.
  Future<ServiceOrderDto?> prevezmiZakazku(String orderId);

  /// `PUT /orders/{id}/envelope` - obálka s klíčem k zakázce. Otázka
  /// (obálka jiné zakázky, jiné pobočky) je [ServiceOrderException]
  /// s kódem z [otazkyObalky]; [prepsat] ji odsouhlasí.
  Future<ServiceOrderDto?> priradObalku(
    String orderId,
    String kod, {
    bool prepsat = false,
  });

  /// `DELETE /orders/{id}/envelope` - uvolní obálku zakázky.
  Future<ServiceOrderDto?> uvolniObalku(String orderId);

  /// `GET /envelopes/{code}` - komu obálka patří. `null` = v evidenci není.
  Future<NalezenaObalka?> najdiObalku(String kod);

  /// `PUT /orders/{id}/bodyshop-plan` - zaplánovat na klempírnu/lakovnu
  /// nebo plán upravit. Zakázka jiného než klempířského útvaru je
  /// [ServiceOrderException] s hláškou.
  Future<ServiceOrderDto?> ulozPlanKlempirny(
    String orderId,
    PlanKlempirny plan,
  );

  /// `DELETE /orders/{id}/bodyshop-plan` - zrušit plán.
  Future<ServiceOrderDto?> zrusPlanKlempirny(String orderId);

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
