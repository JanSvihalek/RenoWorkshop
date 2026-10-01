import 'package:flutter/material.dart';

import '../layout/rozlozeni.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
  });

  final WorkshopTab active;
  final ValueChanged<WorkshopTab> onSelect;

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
      Icons.search_outlined,
      Icons.search_rounded,
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
    final palette = context.palette;
    final tmava = context.isDarkMode;
    return Container(
      width: Rozlozeni.sirkaNavigace,
      decoration: BoxDecoration(
        color: palette.hlavicka,
        border: tmava
            ? null
            : Border(right: BorderSide(color: palette.hairline2)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: Insets.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.base),
              // Bílý klíč - na bílé liště na navy dlaždici jako ikona aplikace.
              // Pevný rozměr - dokud se obrázek nenačte, dlaždice nesmí
              // splasknout do čárky.
              child: Container(
                width: tmava ? null : 40,
                height: tmava ? null : 40,
                padding: EdgeInsets.all(tmava ? 0 : 4),
                decoration: BoxDecoration(
                  color: tmava ? null : AppColors.primary,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: Image.asset(
                  'assets/icon/png/adaptive/renoworkshop-foreground-432.png',
                  height: tmava ? 34 : 32,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
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
            // Iniciály přihlášeného tu nejsou - jsou v hlavičce zakázek
            // i s volbou vzhledu, dvakrát vedle sebe působily jako chyba.
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
    final palette = context.palette;
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
            color: jeAktivni ? palette.hlavickaPrvek : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Column(
            children: [
              Icon(
                ikona,
                size: 22,
                color: jeAktivni
                    ? palette.naHlavicce
                    : palette.naHlavicceTlumene,
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
                        ? palette.naHlavicce
                        : palette.naHlavicceTlumene,
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
