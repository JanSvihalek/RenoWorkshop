import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/rozlozeni.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import 'plan_screen.dart' show cestaPlanovace;

/// Přepínač aplikací RenoWorkshopu (jako mřížka na webu): Zakázky a Plán
/// klempírny - plánovač je obrazovka appky, přihlášení se neopakuje. Na
/// telefonu mřížka v hlavičce zakázek ([PrepinacAplikaci]), na tabletu
/// položka Aplikace v boční navigaci.
Future<void> zobrazPrepinacAplikaci(BuildContext context, WidgetRef ref) {
  void otevriPlanovac(BuildContext panel) {
    Navigator.of(panel).pop();
    context.push(cestaPlanovace);
  }

  final palette = context.palette;
  // Vysune se zleva a zastaví vlevo nahoře u mřížky - jako panel na webu.
  // Na tabletu vedle boční navigace, na telefonu pod hlavičkou.
  final vlevo = context.jeTablet
      ? Rozlozeni.sirkaNavigace + Insets.sm
      : Insets.md;
  final sirka = (MediaQuery.sizeOf(context).width - vlevo - Insets.md).clamp(
    0.0,
    380.0,
  );

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Zavřít',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (panel, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(left: vlevo, top: Insets.base),
          child: Material(
            key: const Key('panel-aplikaci'),
            color: palette.card,
            elevation: 8,
            borderRadius: BorderRadius.circular(Radii.card),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: sirka,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.base,
                  Insets.base,
                  Insets.base,
                  Insets.base,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.sm,
                        0,
                        Insets.sm,
                        Insets.sm,
                      ),
                      child: Text(
                        'APLIKACE RENOWORKSHOP',
                        style: AppTextStyles.overline.copyWith(
                          color: panel.palette.muted,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const _Dlazdice(
                      ikona: Icons.build_rounded,
                      nazev: 'Zakázky',
                      popis:
                          'Zakázky na dílně - stavy, fotky, dokumenty, obálky',
                      aktualni: true,
                    ),
                    const SizedBox(height: Insets.xs),
                    _Dlazdice(
                      key: const Key('aplikace-plan'),
                      ikona: Icons.calendar_month_rounded,
                      nazev: 'Plán klempírny',
                      popis: 'Plánování klempírny a lakovny a průběh na dílně',
                      onTap: () => otevriPlanovac(panel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animace, _, dite) {
      final krivka = CurvedAnimation(
        parent: animace,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(krivka),
        child: dite,
      );
    },
  );
}

/// Mřížka přepínače aplikací v hlavičce zakázek na telefonu. Úzká - širší
/// tlačítko by zalomilo nadpis „Zakázky na dílně".
class PrepinacAplikaci extends ConsumerWidget {
  const PrepinacAplikaci({super.key, required this.naTmavem});

  /// V navy hlavičce je ikona bílá, ve světlém vzhledu tmavá.
  final bool naTmavem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Aplikace RenoWorkshopu',
      child: GestureDetector(
        key: const Key('prepinac-aplikaci'),
        onTap: () => zobrazPrepinacAplikaci(context, ref),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 28,
          height: 34,
          child: Icon(
            Icons.apps_rounded,
            size: 24,
            color: naTmavem ? Colors.white : context.palette.text,
          ),
        ),
      ),
    );
  }
}

/// Jedna aplikace v přepínači - aktuální podbarvená se štítkem
/// „Jste zde", ostatní se otevřou klepnutím.
class _Dlazdice extends StatelessWidget {
  const _Dlazdice({
    super.key,
    required this.ikona,
    required this.nazev,
    required this.popis,
    this.aktualni = false,
    this.onTap,
  });

  final IconData ikona;
  final String nazev;
  final String popis;
  final bool aktualni;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: aktualni ? palette.background : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(ikona, color: Colors.white, size: 22),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nazev,
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      popis,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              if (aktualni)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Jste zde',
                    style: AppTextStyles.metaSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
