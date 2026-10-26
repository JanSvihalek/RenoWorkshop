import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../diagnostika/presentation/diagnostika_karta.dart';
import '../../../fotodokumentace/presentation/controllers/fotky_providers.dart';
import '../../../fotodokumentace/presentation/widgets/dokumenty_heliosu_karta.dart';
import '../../../fotodokumentace/presentation/widgets/fotodokumentace_karta.dart';
import '../../../prijem/domain/entities/prijem.dart';
import '../../../prijem/presentation/controllers/prijem_providers.dart';
import '../../../ulozenky/presentation/ulozenky_karta.dart';

/// Sekce detailu zakázky podle Janova návrhu (26. 10. 2026) - vlevo menu
/// s počty, uprostřed vybraná sekce, vpravo pořád průběh. Jako na webu.
enum SekceDetailu {
  zavady('Závady/úkony'),
  prijem('Příjem'),
  dokumenty('Dokumenty'),
  ulozenky('Uloženky pneu');

  const SekceDetailu(this.nazev);

  final String nazev;
}

/// Odznak příjmu: – nezahájen, 3/10 rozpracovaný, ✓ dokončený.
String odznakPrijmu(Prijem? prijem) => switch (prijem?.stav) {
  null || StavPrijmu.nezahajen => '–',
  StavPrijmu.dokoncen => '✓',
  StavPrijmu.rozpracovany =>
    '${prijem!.pocetVyplnenych}/${prijem.pocetPovinnych}',
};

/// Počet dokumentů pro menu - fotky, dokumenty ve složce, protokoly
/// diagnostiky a doklady z Heliosu.
int pocetDokumentu(WidgetRef ref, String orderId) =>
    (ref.watch(fotkyZakazkyProvider(orderId)).valueOrNull?.length ?? 0) +
    (ref.watch(dokumentyZakazkyProvider(orderId)).valueOrNull?.length ?? 0) +
    (ref.watch(diagnostikaZakazkyProvider(orderId)).valueOrNull?.length ?? 0) +
    (ref.watch(dokumentyHeliosuProvider(orderId)).valueOrNull?.length ?? 0);

/// Menu sekcí - svisle vlevo, na úzkém displeji vodorovně nahoře.
class MenuSekci extends ConsumerWidget {
  const MenuSekci({
    super.key,
    required this.orderId,
    required this.pocetZavad,
    required this.vybrana,
    required this.onVyber,
    this.svisle = true,
  });

  final String orderId;
  final int pocetZavad;
  final SekceDetailu vybrana;
  final ValueChanged<SekceDetailu> onVyber;
  final bool svisle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final odznaky = {
      SekceDetailu.zavady: '$pocetZavad',
      SekceDetailu.prijem: odznakPrijmu(
        ref.watch(prijemZakazkyProvider(orderId)).valueOrNull,
      ),
      SekceDetailu.dokumenty: '${pocetDokumentu(ref, orderId)}',
      SekceDetailu.ulozenky:
          '${ref.watch(ulozenkyZakazkyProvider(orderId)).valueOrNull?.where((u) => u.aktivni).length ?? 0}',
    };

    final polozky = [
      for (final sekce in SekceDetailu.values)
        _Polozka(
          key: Key('sekce-${sekce.name}'),
          nazev: sekce.nazev,
          odznak: odznaky[sekce]!,
          vybrana: sekce == vybrana,
          svisle: svisle,
          onTap: () => onVyber(sekce),
        ),
    ];

    if (!svisle) {
      return Material(
        color: palette.card,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.xs,
          ),
          child: Row(children: polozky),
        ),
      );
    }
    return Material(
      color: palette.card,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.lg,
          Insets.md,
          Insets.lg,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Insets.md, bottom: Insets.sm),
            child: Text(
              'PRÁCE',
              style: AppTextStyles.overline.copyWith(color: palette.muted),
            ),
          ),
          for (final p in polozky) ...[p, const SizedBox(height: Insets.xxs)],
        ],
      ),
    );
  }
}

class _Polozka extends StatelessWidget {
  const _Polozka({
    super.key,
    required this.nazev,
    required this.odznak,
    required this.vybrana,
    required this.svisle,
    required this.onTap,
  });

  final String nazev;
  final String odznak;
  final bool vybrana;
  final bool svisle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Text(
      nazev,
      style: AppTextStyles.cardBody.copyWith(
        color: palette.text,
        fontWeight: vybrana ? FontWeight.w700 : FontWeight.w500,
      ),
    );
    final cislo = Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 1),
      decoration: BoxDecoration(
        color: vybrana ? AppColors.primary : palette.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        odznak,
        textAlign: TextAlign.center,
        style: AppTextStyles.metaSmall.copyWith(
          color: vybrana ? Colors.white : palette.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Semantics(
      selected: vybrana,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.input),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.md,
          ),
          decoration: BoxDecoration(
            color: vybrana ? AppColors.accent.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(Radii.input),
            border: svisle
                ? Border(
                    left: BorderSide(
                      color: vybrana ? AppColors.accent : Colors.transparent,
                      width: 3,
                    ),
                  )
                : Border(
                    bottom: BorderSide(
                      color: vybrana ? AppColors.accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
          ),
          child: svisle
              ? Row(
                  children: [
                    Expanded(child: text),
                    cislo,
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    text,
                    const SizedBox(width: Insets.sm),
                    cislo,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Dokumenty - tři samostatné karty pod sebou: fotodokumentace (náhledy),
/// ISTA/ISPA protokoly z diagnostiky a doklady z Heliosu.
class DokumentyKarta extends StatelessWidget {
  const DokumentyKarta({
    super.key,
    required this.orderId,
    this.onFotodokumentace,
  });

  final String orderId;
  final VoidCallback? onFotodokumentace;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('dokumenty-karta'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onFotodokumentace != null) ...[
          FotodokumentaceKarta(orderId: orderId, onOtevrit: onFotodokumentace!),
          const SizedBox(height: Insets.base),
        ],
        DiagnostikaKarta(orderId: orderId),
        const SizedBox(height: Insets.base),
        DokumentyHeliosuKarta(orderId: orderId),
      ],
    );
  }
}
