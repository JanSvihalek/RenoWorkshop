import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/placeholder_auth_repository.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/auth_repository.dart';

/// Jediné místo, kde se vybírá implementace přihlášení.
/// Fáze 2: `PlaceholderAuthRepository()` -> `FirebaseAuthRepository(...)`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => PlaceholderAuthRepository(),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Přihlášený zaměstnanec, nebo `null` - pro hlavičku a autora poznámek.
final currentEmployeeProvider = Provider<Employee?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSignedIn ? state.employee : null;
});

/// Zda vůbec nabízet biometrické tlačítko.
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(authRepositoryProvider).isBiometricSignInAvailable(),
);

/// Řídí přihlašovací flow. Reálné ověření přijde ve fázi 2 výměnou
/// [authRepositoryProvider] - tenhle controller ani UI se měnit nebudou.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final employee = ref.read(authRepositoryProvider).currentEmployee;
    return employee == null ? const AuthSignedOut() : AuthSignedIn(employee);
  }

  Future<void> signIn(SignInMethod method) async {
    if (state is AuthSigningIn) return;
    state = AuthSigningIn(method);

    final repository = ref.read(authRepositoryProvider);
    try {
      final employee = switch (method) {
        SignInMethod.microsoftSso => await repository.signInWithMicrosoft(),
        SignInMethod.biometric => await repository.signInWithBiometrics(),
      };
      state = AuthSignedIn(employee);
    } on AuthException catch (error) {
      state = AuthSignedOut(errorMessage: error.message);
    } catch (error) {
      state = AuthSignedOut(errorMessage: 'Přihlášení se nezdařilo: $error');
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthSignedOut();
  }
}
