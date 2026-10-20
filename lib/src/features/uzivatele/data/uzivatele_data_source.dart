import '../domain/uzivatele.dart';

/// Správa uživatelů - implementuje ji stejná služba jako zakázky
/// (`GET /users`, `PUT /users/{email}`), jen pro admina.
abstract interface class UzivateleDataSource {
  Future<PrehledUzivatelu> nactiUzivatele();

  /// Role a práva uživatele, i nového. [prava]: kód pořadače -> `R`, `W`,
  /// nebo `null` (žádný přístup).
  Future<void> ulozUzivatele(
    String email, {
    required String role,
    required Map<String, String?> prava,
  });
}
