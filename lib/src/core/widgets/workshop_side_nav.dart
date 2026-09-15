import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/employee.dart';
import '../layout/rozlozeni.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';
import 'workshop_bottom_nav.dart';

/// Svislý navigační pruh pro tablet.
///
/// Na tabletu u stání je obrazovka na šířku a spodní lišta by ukrajovala
/// z výšky, které je málo. Pruh vlevo ji nechá celou seznamu a detailu
/// a drží se blízko ruky, která tablet přidržuje.
///
/// Zůstává tmavý i ve světlém motivu: odděluje navigaci od obsahu
/// a odpovídá hlavičkám, které jsou navy v obou motivech.
class WorkshopSideNav extends StatelessWidget {
  const WorkshopSideNav({
    super.key,
    required this.active,
    required this.onSelect,
    this.employee,
  });

  final WorkshopTab active;
  final ValueChanged<WorkshopTab> onSelect;

  /// Přihlášený zaměstnanec - iniciály dole v pruhu.
  final Employee? employee;

  static const _polozky = [
    (
      WorkshopTab.orders,
      'Zakázky',
      Icons.assignment_outlined,
      Icons.assignment,
    ),
    (WorkshopTab.prijem, 'Příjem', Icons.fact_check_outlined, Icons.fact_check),
    (
      WorkshopTab.vyhledavani,
      'Vozidla',
      Icons.directions_car_outlined,
      Icons.directions_car,
    ),
    (
      WorkshopTab.settings,
      'Nastavení',
      Icons.settings_outlined,
      Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Rozlozeni.sirkaNavigace,
      color: AppColors.primary,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: Insets.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.base),
              child: Image.asset(
                'assets/icon/png/adaptive/renoworkshop-foreground-432.png',
                height: 34,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: Insets.xxl),
            for (final (tab, popisek, ikona, ikonaAktivni) in _polozky) ...[
              _Polozka(
                popisek: popisek,
                ikona: tab == active ? ikonaAktivni : ikona,
                jeAktivni: tab == active,
                onTap: () => onSelect(tab),
              ),
              const SizedBox(height: Insets.sm),
            ],
            const Spacer(),
            if (employee != null) ...[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  employee!.initials,
                  style: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: Insets.xxl),
            ],
          ],
        ),
      ),
    );
  }
}

class _Polozka extends StatelessWidget {
  const _Polozka({
    required this.popisek,
    required this.ikona,
    required this.jeAktivni,
    required this.onTap,
  });

  final String popisek;
  final IconData ikona;
  final bool jeAktivni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: jeAktivni,
      label: popisek,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.sm),
          padding: const EdgeInsets.symmetric(
            vertical: Insets.base,
            horizontal: Insets.xs,
          ),
          decoration: BoxDecoration(
            color: jeAktivni
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Column(
            children: [
              Icon(
                ikona,
                size: 22,
                color: jeAktivni
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 4),
              // Delší popisek („Nastavení") se radši zmenší, než aby se
              // dotýkal okrajů dlaždice nebo se zalomil.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  popisek,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTextStyles.metaSmall.copyWith(
                    fontSize: 10.5,
                    color: jeAktivni
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
