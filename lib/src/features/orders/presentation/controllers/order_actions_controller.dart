import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/log_udalosti_provider.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/obalka_klice.dart';
import '../../domain/entities/plan_klempirny.dart';
import '../../domain/repositories/service_order_repository.dart';
import 'orders_providers.dart';
import '../../../plan/presentation/plan_providers.dart';

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

  /// Zakázka mimo dílnu se do detailu nepropíše přes seznam - načte se
  /// znovu ze serveru. U zakázky na dílně to nic nestojí, nikdo ji tak
  /// nesleduje.
  void _obnovMimoDilnu(String orderId) =>
      ref.invalidate(zakazkaMimoDilnuProvider(orderId));

  /// Zápis do logu událostí - ať je v posloupnosti kroků uživatele vidět
  /// i práce s postupem a poznámkami. Text poznámky se nezapisuje, je
  /// v tabulce poznámek; smazaný stav si do logu zapíše služba celý.
  void _zaloguj(String nazev, String orderId, {String? detail}) => ref
      .read(logUdalostiProvider)
      .udalost(nazev, detail: detail, zakazka: orderId);

  /// Přidá dílenský stav do historie zakázky.
  ///
  /// Buď [kod] z číselníku, nebo [nazev] s vlastním textem. Vrací `true`
  /// při úspěchu; chyba se propíše do stavu controlleru.
  Future<bool> pridejStav(
    String orderId, {
    String? kod,
    String? nazev,
    String? poznamka,
    String? misto,
  }) async {
    if (kod == null && (nazev == null || nazev.trim().isEmpty)) return false;

    state = const AsyncLoading();
    try {
      await _repository.pridejStav(
        orderId,
        kod: kod,
        nazev: nazev?.trim(),
        poznamka: poznamka?.trim().isEmpty ?? true ? null : poznamka!.trim(),
        misto: misto?.trim(),
      );
      _zaloguj('stav_pridan', orderId, detail: kod ?? 'vlastní text');
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
      return true;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return false;
    }
  }

  /// Přiřadí zakázce obálku s klíčem.
  ///
  /// Obálka jiné rozdělané zakázky nebo jiné pobočky vrátí [otazka] -
  /// po potvrzení technikem zavolat znovu s [prepsat]. Jiná chyba je
  /// v [chyba] (a ve stavu controlleru).
  Future<({bool hotovo, String? otazka, String? chyba})> priradObalku(
    String orderId,
    String kod, {
    bool prepsat = false,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.priradObalku(orderId, kod, prepsat: prepsat);
      _zaloguj('obalka_prirazena', orderId, detail: kod);
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
      return (hotovo: true, otazka: null, chyba: null);
    } on ServiceOrderException catch (error, stackTrace) {
      if (otazkyObalky.contains(error.kod)) {
        state = const AsyncData(null);
        return (hotovo: false, otazka: error.message, chyba: null);
      }
      state = AsyncError(error.message, stackTrace);
      return (hotovo: false, otazka: null, chyba: error.message);
    }
  }

  /// Uvolní obálku zakázky - klíč z ní odešel jinak než se zákazníkem.
  Future<bool> uvolniObalku(String orderId) async {
    state = const AsyncLoading();
    try {
      await _repository.uvolniObalku(orderId);
      _zaloguj('obalka_uvolnena', orderId);
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
      return true;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return false;
    }
  }

  /// Zaplánuje zakázku na klempírnu/lakovnu, nebo plán upraví. Chyba
  /// (třeba zakázka jiného útvaru) jde do [chyba].
  Future<String?> ulozPlanKlempirny(String orderId, PlanKlempirny plan) async {
    state = const AsyncLoading();
    try {
      await _repository.ulozPlanKlempirny(orderId, plan);
      _zaloguj('plan_klempirny_ulozen', orderId, detail: plan.kodLaku);
      _poZmenePlanu(orderId);
      state = const AsyncData(null);
      return null;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return error.message;
    }
  }

  Future<String?> zrusPlanKlempirny(String orderId) async {
    state = const AsyncLoading();
    try {
      await _repository.zrusPlanKlempirny(orderId);
      _zaloguj('plan_klempirny_zrusen', orderId);
      _poZmenePlanu(orderId);
      state = const AsyncData(null);
      return null;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return error.message;
    }
  }

  /// Plán se změnil - zakázka mimo dílnu i záložka Plán se načtou znovu.
  void _poZmenePlanu(String orderId) {
    _obnovMimoDilnu(orderId);
    ref.invalidate(planKlempirnyProvider);
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
      _zaloguj('poznamka_pridana', orderId, detail: 'znaků ${trimmed.length}');
      _obnovMimoDilnu(orderId);
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
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
    }
  }

  /// Přepíše předmět opravy. Prázdný text ho smaže - i to je platná úprava.
  Future<bool> ulozPredmetOpravy(String orderId, String text) async {
    state = const AsyncLoading();
    try {
      await _repository.ulozPredmetOpravy(orderId, text.trim());
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
      return true;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return false;
    }
  }

  /// Zpracovatelem zakázky se stane přihlášený. Když ho server podle
  /// e-mailu v Heliosu nenajde, chyba to řekne - pak se vybere ze seznamu.
  Future<bool> prevezmiZakazku(String orderId) async {
    state = const AsyncLoading();
    try {
      await _repository.prevezmiZakazku(orderId);
      _zaloguj('zakazka_prevzata', orderId);
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
      return true;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return false;
    }
  }

  /// Přiřadí zpracovatele zakázky; `null` ji uvolní.
  Future<bool> nastavZpracovatele(String orderId, int? zamestnanecId) async {
    state = const AsyncLoading();
    try {
      await _repository.nastavZpracovatele(orderId, zamestnanecId);
      _zaloguj(
        zamestnanecId == null ? 'zakazka_uvolnena' : 'zpracovatel_prirazen',
        orderId,
        detail: zamestnanecId?.toString(),
      );
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
      return true;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return false;
    }
  }

  /// Smaže záznam z historie stavů - oprava omylem přidaného stavu.
  Future<bool> smazStav(String orderId, String zaznamId) async {
    state = const AsyncLoading();
    try {
      await _repository.smazStav(orderId, zaznamId);
      _zaloguj('stav_smazan', orderId);
      _obnovMimoDilnu(orderId);
      state = const AsyncData(null);
      return true;
    } on ServiceOrderException catch (error, stackTrace) {
      state = AsyncError(error.message, stackTrace);
      return false;
    }
  }
}
