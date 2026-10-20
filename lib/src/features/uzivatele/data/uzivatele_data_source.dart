import '../domain/uzivatele.dart';

/// Správa uživatelů - implementuje ji stejná služba jako zakázky
/// (`GET /users`, `PUT /users/{email}`), jen pro admina.
abstract interface class UzivateleDataSource {
  Future<PrehledUzivatelu> nactiUzivatele();

  /// Role a práva uživatele, i nového. [prava]: kód pořadače -> `R`, `W`,
  /// nebo `null` (žádný přístup). [planovac]: pobočka plánovače -> `W`
  /// plánovat, `R` prohlížet, `null` nic; `null` celé = beze změny.
  Future<void> ulozUzivatele(
    String email, {
    required String role,
    required Map<String, String?> prava,
    Map<String, String?>? planovac,
  });
}
