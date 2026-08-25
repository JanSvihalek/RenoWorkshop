import '../../orders/domain/entities/branch.dart';
import '../domain/entities/employee.dart';
import '../domain/repositories/auth_repository.dart';

/// FÁZE 1 - placeholder bez reálného ověřování.
///
/// Vrací pevně daného zaměstnance po simulovaném zpoždění, aby šlo proklikat
/// celý flow. Nic neukládá a nikam se nepřipojuje.
///
/// Náhrada ve fázi 2: `FirebaseAuthRepository` (Firebase Auth + Microsoft
/// OIDC / Entra ID). Zbytek appky se měnit nebude - závisí jen na
/// [AuthRepository] a na providerech v `auth_providers.dart`.
class PlaceholderAuthRepository implements AuthRepository {
  PlaceholderAuthRepository({
    this.ssoDelay = const Duration(milliseconds: 1400),
    this.biometricDelay = const Duration(milliseconds: 1000),
  });

  final Duration ssoDelay;
  final Duration biometricDelay;

  static const Employee _demoEmployee = Employee(
    id: 'placeholder-employee',
    displayName: 'Jan Dvořák',
    email: 'jan.dvorak@renocar.cz',
    role: EmployeeRole.mechanic,
    homeBranch: Branch.brno,
  );

  Employee? _currentEmployee;

  @override
  Employee? get currentEmployee => _currentEmployee;

  @override
  Future<bool> isBiometricSignInAvailable() async => true;

  @override
  Future<Employee> signInWithMicrosoft() async {
    await Future<void>.delayed(ssoDelay);
    return _currentEmployee = _demoEmployee;
  }

  @override
  Future<Employee> signInWithBiometrics() async {
    await Future<void>.delayed(biometricDelay);
    return _currentEmployee = _demoEmployee;
  }

  @override
  Future<void> signOut() async {
    _currentEmployee = null;
  }
}
