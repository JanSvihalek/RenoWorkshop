import 'employee.dart';

/// Způsob přihlášení nabízený na login obrazovce.
enum SignInMethod {
  /// Firemní účet přes Microsoft Entra ID (v produkci Firebase Auth + OIDC).
  microsoftSso,

  /// Biometrie nad uloženým refresh tokenem posledního přihlášení.
  biometric,
}

/// Stav přihlášení. Router se podle něj rozhoduje o přesměrování.
sealed class AuthState {
  const AuthState();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.errorMessage});

  /// Text chyby z posledního pokusu, nebo `null`.
  final String? errorMessage;
}

class AuthSigningIn extends AuthState {
  const AuthSigningIn(this.method);

  final SignInMethod method;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.employee);

  final Employee employee;
}
