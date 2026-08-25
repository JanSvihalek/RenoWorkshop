import '../entities/employee.dart';

/// Kontrakt přihlášení zaměstnance.
///
/// FÁZE 1: plní ho [PlaceholderAuthRepository] - žádné reálné ověření.
/// FÁZE 2: `FirebaseAuthRepository` nad Firebase Auth s poskytovatelem
/// Microsoft (OIDC / Entra ID), stejně jako v projektu RenoCharge:
///   - `OAuthProvider('microsoft.com')` s tenant ID RENOCAR,
///   - `local_auth` pro biometrické odemčení uloženého refresh tokenu,
///   - token v secure storage (Keychain / Keystore).
/// Registrace účtů se nikdy neotevírá veřejně - účty spravuje IT přes Entra ID.
abstract interface class AuthRepository {
  /// Aktuálně přihlášený zaměstnanec, nebo `null`.
  Employee? get currentEmployee;

  /// Je na zařízení zaregistrovaná biometrie a uložený účet?
  /// Pokud ne, login obrazovka biometrické tlačítko skryje.
  Future<bool> isBiometricSignInAvailable();

  /// Přihlášení firemním účtem (interaktivní OIDC flow).
  Future<Employee> signInWithMicrosoft();

  /// Odemčení posledního přihlášení biometrií.
  Future<Employee> signInWithBiometrics();

  Future<void> signOut();
}

/// Chyba přihlášení prezentovatelná uživateli.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
