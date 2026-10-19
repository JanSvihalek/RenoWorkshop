import '../entities/obalka_klice.dart';
import '../entities/dilensky_stav.dart';
import '../entities/service_order.dart';
import '../entities/zpracovatel.dart';

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

  /// Hledání v archivu - i mezi zakázkami, které už na dílně nestojí.
  ///
  /// Neplní stream ani mezipaměť: je to jednorázový dotaz na server,
  /// jehož výsledek se zobrazí zvlášť a zase zmizí.
  Future<List<ServiceOrder>> searchArchive(String query);

  /// Přidá dílenský stav do historie zakázky.
  ///
  /// Buď [kod] z číselníku, nebo [nazev] s vlastním textem. Stav se
  /// přidává, neposouvá - na klempírně se sled prací vrací i přeskakuje.
  Future<ServiceOrder> pridejStav(
    String orderId, {
    String? kod,
    String? nazev,
    String? poznamka,

    /// Kde vůz po tomhle kroku stojí. `null` = neměnit, prázdný text
    /// místo smaže.
    String? misto,
  });

  /// Přepíše předmět opravy; prázdný text ho smaže.
  Future<ServiceOrder> ulozPredmetOpravy(String orderId, String text);

  /// Smaže záznam z historie stavů - oprava omylem přidaného stavu.
  Future<ServiceOrder> smazStav(String orderId, String zaznamId);

  /// Koho lze zakázce přiřadit jako zpracovatele.
  Future<NabidkaZpracovatelu> nabidkaZpracovatelu(
    String orderId, {
    bool vsichni = false,
  });

  /// Přiřadí zpracovatele; `null` zakázku uvolní.
  Future<ServiceOrder> nastavZpracovatele(String orderId, int? zamestnanecId);

  /// Zpracovatelem se stane přihlášený.
  Future<ServiceOrder> prevezmiZakazku(String orderId);

  /// Obálka s klíčem k zakázce. Obálka jiné rozdělané zakázky nebo jiné
  /// pobočky skončí [ServiceOrderException] s kódem z [otazkyObalky];
  /// s [prepsat] se přiřadí stejně.
  Future<ServiceOrder> priradObalku(
    String orderId,
    String kod, {
    bool prepsat = false,
  });

  /// Uvolní obálku zakázky - klíč z ní odešel jinak než se zákazníkem.
  Future<ServiceOrder> uvolniObalku(String orderId);

  /// Komu naskenovaná obálka patří. `null` = obálka v evidenci není.
  Future<NalezenaObalka?> najdiObalku(String kod);

  /// Nabídka stavů z číselníku na serveru.
  Future<List<NabidkaStavu>> nabidkaStavu();

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
  const ServiceOrderException(this.message, {this.kod});

  final String message;

  /// Kód chyby ze serveru (`envelope_in_use`…), když ho poslal. Podle něj
  /// aplikace pozná otázku od chyby - viz [otazkyObalky].
  final String? kod;

  @override
  String toString() => 'ServiceOrderException: $message';
}

class ServiceOrderNotFoundException extends ServiceOrderException {
  const ServiceOrderNotFoundException(this.orderId)
    : super('Zakázka $orderId nebyla nalezena.');

  final String orderId;
}
