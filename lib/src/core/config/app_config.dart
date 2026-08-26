/// Nastavení, která se liší podle prostředí nebo se mohou měnit bez zásahu
/// do logiky. Zatím konstanty, později se mohou načítat z Remote Configu.
abstract final class AppConfig {
  /// Tenant RENOCAR v Entra ID. Předává se do OIDC flow jako parametr
  /// `tenant`, takže přihlašovací dialog rovnou nabídne firemní účet
  /// a cizí účty (osobní Microsoft, jiná firma) neprojdou.
  ///
  /// Stejný tenant používá i RenoDesk.
  static const String microsoftTenantId =
      '8b1f4bcf-87b4-4781-b523-badd7523db1d';

  /// Rozsahy, které si appka od Microsoftu žádá. `User.Read` stačí na jméno
  /// a e-mail; víc zatím nepotřebujeme.
  static const List<String> microsoftScopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
  ];
}
