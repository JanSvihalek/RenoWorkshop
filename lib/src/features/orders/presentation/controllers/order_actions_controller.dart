import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/log_udalosti_provider.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
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
  }) async {
    if (kod == null && (nazev == null || nazev.trim().isEmpty)) return false;

    state = const AsyncLoading();
    try {
      await _repository.pridejStav(
        orderId,
        kod: kod,
        nazev: nazev?.trim(),
        poznamka: poznamka?.trim().isEmpty ?? true ? null : poznamka!.trim(),
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
