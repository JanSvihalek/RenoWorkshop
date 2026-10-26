import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';

/// Bílá karta v detailu zakázky - společný podklad pro všechny sekce.
class DetailCard extends StatelessWidget {
  const DetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.xl),
    this.zHeliosu = false,
    this.zIspi = false,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Data z Heliosu, jen ke čtení (závady, dokumenty z EDM) - karta je
  /// zelená jako stav z Heliosu, ať je na první pohled jasné, že se do
  /// ní z dílny nezapisuje.
  final bool zHeliosu;

  /// Dokumenty ze serveru ISPI - karta je světle modrá.
  final bool zIspi;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tmavy = Theme.of(context).brightness == Brightness.dark;
    final ton = zHeliosu
        ? (AppColors.heliosGreen, AppColors.heliosZelena(context))
        : zIspi
        ? (AppColors.ispiBlue, AppColors.ispiModra(context))
        : null;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: ton == null
            ? palette.card
            : Color.alphaBlend(
                ton.$1.withValues(alpha: tmavy ? 0.16 : 0.07),
                palette.card,
              ),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: ton == null
              ? palette.hairline
              : ton.$2.withValues(alpha: 0.55),
        ),
      ),
      child: child,
    );
  }
}

/// Nadpis sekce ("POSTUP ZAKÁZKY"). [barva] jen u karet z Heliosu.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.barva});

  final String text;
  final Color? barva;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.overline.copyWith(
        color: barva ?? context.palette.muted,
      ),
    );
  }
}

/// Zámek s popiskem v záhlaví karty z Heliosu - zapisuje se tam v Heliosu,
/// ne v aplikaci.
class HeliosZnacka extends StatelessWidget {
  const HeliosZnacka({super.key, this.text = 'HELIOS · JEN KE ČTENÍ'});

  final String text;

  @override
  Widget build(BuildContext context) {
    final zelena = AppColors.heliosZelena(context);
    return Row(
      key: const Key('helios-znacka'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: zelena),
        const SizedBox(width: 3),
        Text(
          text,
          style: AppTextStyles.overline.copyWith(color: zelena, fontSize: 10),
        ),
      ],
    );
  }
}
