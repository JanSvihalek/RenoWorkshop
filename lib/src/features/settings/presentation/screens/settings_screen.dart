import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/workshop_bottom_nav.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../domain/entities/nastaveni.dart';
import '../controllers/nastaveni_controller.dart';

/// Nastavení: přihlášený zaměstnanec, vzhled, výchozí filtr seznamu
/// a odhlášení.
///
/// Volby se ukládají do telefonu, ne k účtu - na sdíleném dílenském
/// přístroji jde o pohodlí toho, kdo ho drží v ruce.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.onSelectTab});

  final ValueChanged<WorkshopTab> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final employee = ref.watch(currentEmployeeProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.xl,
                Insets.xl,
                Insets.giant,
              ),
              children: [
                if (employee != null) _EmployeeCard(employee: employee),
                const SizedBox(height: Insets.base),
                const _VzhledCard(),
                const SizedBox(height: Insets.base),
                const _VychoziFiltrCard(),
                const SizedBox(height: Insets.base),
                const _AboutCard(),
                const SizedBox(height: Insets.huge),
                _SignOutButton(onSignOut: () => _confirmSignOut(context, ref)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: WorkshopBottomNav(
        active: WorkshopTab.settings,
        onSelect: onSelectTab,
      ),
    );
  }

  /// Odhlášení se ptá schválně: dílenský telefon se drží v rukavicích
  /// a omylem odhlášený kolega se pak musí znovu prokazovat.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Odhlásit se?'),
        content: const Text(
          'Příště se budete muset znovu přihlásit firemním účtem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odhlásit'),
          ),
        ],
      ),
    );

    if (potvrzeno ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        Insets.xxl,
        topInset + Insets.xl,
        Insets.xxl,
        Insets.xl,
      ),
      child: Text(
        'Nastavení',
        style: AppTextStyles.appBarTitle(
          isIOS: context.isIOS,
        ).copyWith(color: Colors.white),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _Card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              employee.initials,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.displayName,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.email,
                  style: AppTextStyles.meta.copyWith(color: palette.muted),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  employee.role.label,
                  style: AppTextStyles.metaSmall.copyWith(
                    color: palette.muted2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Volba světlého a tmavého vzhledu.
class _VzhledCard extends ConsumerWidget {
  const _VzhledCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vybrany = ref.watch(nastaveniProvider).vzhled;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VZHLED',
            style: AppTextStyles.overline.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.base),
          // Přepínač přes celou šířku - tři velké terče se trefují líp
          // než položky v rozbalovacím seznamu.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<RezimVzhledu>(
              segments: [
                for (final rezim in RezimVzhledu.values)
                  ButtonSegment(value: rezim, label: Text(rezim.label)),
              ],
              selected: {vybrany},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                textStyle: AppTextStyles.cardBody,
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: Colors.white,
              ),
              onSelectionChanged: (vyber) =>
                  ref.read(nastaveniProvider.notifier).zmenVzhled(vyber.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pobočka a útvar, na které se seznam zakázek otevře.
class _VychoziFiltrCard extends ConsumerWidget {
  const _VychoziFiltrCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final nastaveni = ref.watch(nastaveniProvider);
    final pobocky = ref.watch(availableBranchesProvider);
    final utvary = ref.watch(
      departmentsForBranchProvider(nastaveni.vychoziPobocka),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VÝCHOZÍ FILTR',
                style: AppTextStyles.overline.copyWith(color: palette.muted),
              ),
              if (nastaveni.maVychoziFiltr)
                GestureDetector(
                  onTap: () =>
                      ref.read(nastaveniProvider.notifier).zrusVychoziFiltr(),
                  child: Text(
                    'Zrušit',
                    style: AppTextStyles.metaSmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            'Seznam zakázek se otevře rovnou takto vyfiltrovaný.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted2),
          ),
          const SizedBox(height: Insets.base),
          if (pobocky.isEmpty)
            Text(
              'Pobočky se nabídnou, jakmile se načtou zakázky.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            )
          else ...[
            _Vyber(
              popisek: 'Pobočka',
              hodnota: nastaveni.vychoziPobocka,
              moznosti: {
                for (final pobocka in pobocky) pobocka.code: pobocka.label,
              },
              onZmena: (kod) =>
                  ref.read(nastaveniProvider.notifier).zmenVychoziPobocku(kod),
            ),
            // Útvar dává smysl teprve nad vybranou pobočkou - jinak by
            // se nabízely útvary z celé firmy.
            if (nastaveni.vychoziPobocka != null && utvary.isNotEmpty) ...[
              const SizedBox(height: Insets.sm),
              _Vyber(
                popisek: 'Útvar',
                hodnota: nastaveni.vychoziUtvar,
                moznosti: {for (final utvar in utvary) utvar.code: utvar.label},
                onZmena: (kod) =>
                    ref.read(nastaveniProvider.notifier).zmenVychoziUtvar(kod),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Řádek s rozbalovacím výběrem. `null` znamená „vše".
class _Vyber extends StatelessWidget {
  const _Vyber({
    required this.popisek,
    required this.hodnota,
    required this.moznosti,
    required this.onZmena,
  });

  final String popisek;
  final String? hodnota;
  final Map<String, String> moznosti;
  final ValueChanged<String?> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: Text(
            popisek,
            style: AppTextStyles.cardBody.copyWith(color: palette.muted),
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: moznosti.containsKey(hodnota) ? hodnota : null,
            isDense: true,
            borderRadius: BorderRadius.circular(Radii.input),
            style: AppTextStyles.cardBody.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w600,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Vše')),
              for (final polozka in moznosti.entries)
                DropdownMenuItem(
                  value: polozka.key,
                  child: Text(polozka.value),
                ),
            ],
            onChanged: onZmena,
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O APLIKACI',
            style: AppTextStyles.overline.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Insets.md),
          _Row(
            label: 'Zdroj dat',
            // Užitečné při hlášení chyby: ukázková data vypadají stejně
            // jako ostrá, ale znamenají něco jiného.
            value: AppConfig.pouzivaApi ? 'Servisní systém' : 'Ukázková data',
          ),
          const SizedBox(height: Insets.sm),
          const _Row(label: 'Přihlášení', value: 'Firemní účet Microsoft'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.cardBody.copyWith(color: palette.muted),
        ),
        Text(
          value,
          style: AppTextStyles.cardBody.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      child: child,
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: Sizes.ctaHeight,
      child: OutlinedButton.icon(
        onPressed: onSignOut,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Odhlásit se'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: palette.hairline2),
          textStyle: AppTextStyles.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              context.isIOS ? Radii.ctaIos : Radii.ctaAndroid,
            ),
          ),
        ),
      ),
    );
  }
}
