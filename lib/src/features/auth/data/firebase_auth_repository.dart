import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/config/app_config.dart';
import '../domain/entities/employee.dart';
import '../domain/repositories/auth_repository.dart';

/// Přihlášení firemním účtem RENOCAR přes Firebase Auth a Microsoft OIDC
/// (Entra ID). Registrace účtů se nikdy neotevírá - účty spravuje IT
/// v Entra ID, appka je jen spotřebovává.
///
/// Biometrie neotevírá nové přihlášení: Firebase drží relaci i po zavření
/// appky a Face ID / otisk ji jen odemyká. Když relace není, biometrické
/// tlačítko se na login obrazovce vůbec nenabídne.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, LocalAuthentication? localAuth})
    : _auth = auth ?? FirebaseAuth.instance,
      _localAuth = localAuth ?? LocalAuthentication();

  final FirebaseAuth _auth;
  final LocalAuthentication _localAuth;

  @override
  Employee? get currentEmployee => _mapUser(_auth.currentUser);

  @override
  Future<bool> isBiometricSignInAvailable() async {
    if (_auth.currentUser == null) return false;
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      final dostupne = await _localAuth.getAvailableBiometrics();
      return dostupne.isNotEmpty;
    } on Exception {
      // Zařízení bez biometrie nebo bez oprávnění - tlačítko prostě skryjeme.
      return false;
    }
  }

  @override
  Future<Employee> signInWithMicrosoft() async {
    try {
      final provider = OAuthProvider('microsoft.com')
        ..setCustomParameters({
          // Bez tohohle by dialog nabídl i osobní účty Microsoftu.
          'tenant': AppConfig.microsoftTenantId,
          'prompt': 'select_account',
        })
        ..setScopes(AppConfig.microsoftScopes);

      final vysledek = await _auth.signInWithProvider(provider);
      final employee = _mapUser(vysledek.user);
      if (employee == null) {
        throw const AuthException('Přihlášení se nezdařilo, zkuste to znovu.');
      }
      return employee;
    } on FirebaseAuthException catch (chyba) {
      throw AuthException(_zprava(chyba));
    }
  }

  @override
  Future<Employee> signInWithBiometrics() async {
    final employee = currentEmployee;
    if (employee == null) {
      throw const AuthException(
        'Není co odemknout - přihlaste se nejdřív firemním účtem.',
      );
    }

    final bool overeno;
    try {
      overeno = await _localAuth.authenticate(
        localizedReason: 'Odemkněte RenoWorkshop',
        // Jen biometrie, ne PIN k telefonu - odemyká se firemní účet.
        biometricOnly: true,
        // Ať se dialog neshodí, když uživatel na chvíli přepne appku.
        persistAcrossBackgrounding: true,
      );
    } on Exception catch (chyba) {
      throw AuthException('Biometrické ověření selhalo: $chyba');
    }

    if (!overeno) {
      throw const AuthException('Ověření bylo zrušeno.');
    }
    return employee;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Účet z Entra ID na [Employee].
  ///
  /// Role a kmenová pobočka zatím nemají zdroj - přijdou, až se namapují
  /// skupiny z Entra ID. Do té doby má každý přihlášený stejná práva
  /// a seznam ukazuje všechny pobočky.
  Employee? _mapUser(User? user) {
    if (user == null) return null;
    final email = user.email ?? '';
    return Employee(
      id: user.uid,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : _jmenoZEmailu(email),
      email: email,
      role: EmployeeRole.mechanic,
    );
  }

  /// Záchranná síť, když účet nemá vyplněné `displayName`:
  /// `jan.dvorak@renocar.cz` -> `Jan Dvořák` (tedy aspoň `Jan Dvorak`).
  static String _jmenoZEmailu(String email) {
    final zavinac = email.indexOf('@');
    if (zavinac <= 0) return 'Zaměstnanec';
    final casti = email
        .substring(0, zavinac)
        .split(RegExp(r'[._-]+'))
        .where((cast) => cast.isNotEmpty);
    if (casti.isEmpty) return 'Zaměstnanec';
    return casti
        .map((cast) => cast[0].toUpperCase() + cast.substring(1))
        .join(' ');
  }

  static String _zprava(FirebaseAuthException chyba) {
    return switch (chyba.code) {
      'web-context-canceled' ||
      'canceled' ||
      'user-canceled' => 'Přihlášení bylo zrušeno.',
      'network-request-failed' =>
        'Není připojení k síti. Zkuste to znovu, až budete online.',
      'account-exists-with-different-credential' =>
        'Účet už existuje s jiným způsobem přihlášení. Ozvěte se IT.',
      'user-disabled' => 'Účet je zablokovaný. Ozvěte se IT.',
      _ => chyba.message ?? 'Přihlášení se nezdařilo (${chyba.code}).',
    };
  }
}
