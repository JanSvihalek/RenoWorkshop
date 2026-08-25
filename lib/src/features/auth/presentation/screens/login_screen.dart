import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/microsoft_logo.dart';

/// PLACEHOLDER přihlášení - UI kostra bez reálného ověřování.
///
/// Ve fázi 2 se pod stejným UI rozjede Firebase Auth s poskytovatelem
/// Microsoft (Entra ID) a `local_auth` pro biometrii. Registrace zákazníků
/// se tu nikdy neobjeví - účty zaměstnanců spravuje IT.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final isSigningIn = state is AuthSigningIn;
    final biometricAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.03, -1),
            end: Alignment(0.03, 1),
            colors: [
              AppColors.loginGradientTop,
              AppColors.primary,
              AppColors.loginGradientBottom,
            ],
            stops: [0, 0.58, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              30,
              Insets.giant,
              30,
              Insets.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Branding(),
                _SignInBlock(
                  state: state,
                  isSigningIn: isSigningIn,
                  biometricAvailable: biometricAvailable,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Monogram nahradí logo RENOCAR z firemních brand assetů.
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Text(
            'RW',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: Insets.huge),
        Text(
          'RenoWorkshop',
          style: AppTextStyles.loginTitle.copyWith(color: Colors.white),
        ),
        const SizedBox(height: Insets.xxs),
        Text(
          'Stav zakázek na dílně,\nv reálném čase.',
          style: AppTextStyles.loginSubtitle.copyWith(
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

class _SignInBlock extends ConsumerWidget {
  const _SignInBlock({
    required this.state,
    required this.isSigningIn,
    required this.biometricAvailable,
  });

  final AuthState state;
  final bool isSigningIn;
  final bool biometricAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = context.isIOS;
    final controller = ref.read(authControllerProvider.notifier);
    final errorMessage = state is AuthSignedOut
        ? (state as AuthSignedOut).errorMessage
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSigningIn)
          _SigningInIndicator(method: (state as AuthSigningIn).method)
        else ...[
          if (biometricAvailable) ...[
            _PrimaryButton(
              label: isIOS
                  ? 'Přihlásit se přes Face ID'
                  : 'Odemknout otiskem prstu',
              icon: isIOS ? Icons.face_rounded : Icons.fingerprint_rounded,
              onTap: () => controller.signIn(SignInMethod.biometric),
            ),
            const SizedBox(height: Insets.lg),
          ],
          _SecondaryButton(
            label: 'Přihlásit se přes Microsoft',
            onTap: () => controller.signIn(SignInMethod.microsoftSso),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            biometricAvailable
                ? '${isIOS ? 'Face ID' : 'Otisk'} odemkne poslední přihlášení. Jinak pokračujte přes Microsoft SSO.'
                : 'Přihlaste se firemním účtem RENOCAR.',
            textAlign: TextAlign.center,
            style: AppTextStyles.metaSmall.copyWith(
              fontSize: 12.5,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: Insets.base),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.metaSmall.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: Insets.xxl),
        const _NetworkStatusRow(),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: Sizes.primaryButtonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 11),
            Text(
              label,
              style: AppTextStyles.buttonLabel.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: Sizes.secondaryButtonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MicrosoftLogo(),
            const SizedBox(width: 11),
            Text(
              label,
              style: AppTextStyles.buttonLabel.copyWith(
                fontSize: 14.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SigningInIndicator extends StatelessWidget {
  const _SigningInIndicator({required this.method});

  final SignInMethod method;

  @override
  Widget build(BuildContext context) {
    final isIOS = context.isIOS;
    final label = switch (method) {
      SignInMethod.biometric =>
        isIOS ? 'Ověřuji Face ID...' : 'Přiložte prst...',
      SignInMethod.microsoftSso => 'Přihlašování...',
    };
    final hint = switch (method) {
      SignInMethod.biometric => 'Biometrické odemčení uloženého účtu',
      SignInMethod.microsoftSso => 'Ověřuji firemní účet RENOCAR',
    };

    return Column(
      children: [
        Container(
          height: Sizes.primaryButtonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Radii.button),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(width: Insets.base),
              Text(
                label,
                style: AppTextStyles.buttonLabel.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.base),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: AppTextStyles.metaSmall.copyWith(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.42),
          ),
        ),
      ],
    );
  }
}

class _NetworkStatusRow extends StatelessWidget {
  const _NetworkStatusRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: Insets.sm),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.readyGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'FIREMNÍ SÍŤ · ONLINE · V1.0.0',
            style: AppTextStyles.monoLabel.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
