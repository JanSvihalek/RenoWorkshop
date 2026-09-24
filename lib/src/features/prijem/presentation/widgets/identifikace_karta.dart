import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../../../settings/domain/entities/nastaveni.dart';
import '../../../settings/presentation/controllers/nastaveni_controller.dart';
import '../../domain/entities/prijem.dart';
import '../controllers/prijem_providers.dart';

/// Krok 1 příjmu: nalezená zakázka k potvrzení, než technik začne fotit.
///
/// Dřív aplikace po naskenování skočila rovnou do průvodce - u stejných
/// modelů nebo po přeregistraci SPZ ale stojí za to se podívat, že je to
/// opravdu ten vůz. Karta zároveň řekne, jestli příjem už neběží.
class IdentifikaceKarta extends ConsumerWidget {
  const IdentifikaceKarta({
    super.key,
    required this.zakazka,
    required this.naskenovano,
    required this.onZahajit,
    this.onNeniToOno,
    this.sTlacitky = true,
  });

  final ServiceOrder zakazka;

  /// Hledání přišlo ze skeneru, ne z klávesnice - jen do popisku.
  final bool naskenovano;
  final VoidCallback onZahajit;

  /// `null` tlačítko schová - u výběru z víc zakázek není kam „jinam".
  final VoidCallback? onNeniToOno;

  /// `false` - tlačítka jsou jinde, na tabletu u kraje pod palcem
  /// ([TlacitkaIdentifikace]).
  final bool sTlacitky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prijem = ref.watch(prijemZakazkyProvider(zakazka.id)).valueOrNull;
    final stav = prijem?.stav ?? StavPrijmu.nezahajen;

    final (String titulek, IconData ikona, Color barva) = switch (stav) {
      StavPrijmu.nezahajen => (
        'Nalezena otevřená zakázka',
        Icons.check_rounded,
        AppColors.readyGreen,
      ),
      StavPrijmu.rozpracovany => (
        'Příjem rozpracovaný · zkontrolováno '
            '${prijem!.pocetVyplnenych} z ${prijem.pocetPovinnych}',
        Icons.pending_actions_rounded,
        AppColors.repairBlue,
      ),
      StavPrijmu.dokoncen => (
        [
          'Příjem dokončen',
          if (prijem!.dokoncenoAt != null)
            AppDateFormat.date(prijem.dokoncenoAt!),
          ?prijem.dokoncilKdo,
        ].join(' · '),
        Icons.task_alt_rounded,
        AppColors.readyGreen,
      ),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: Column(
        key: Key('identifikace-${zakazka.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: barva, shape: BoxShape.circle),
                child: Icon(ikona, size: 16, color: Colors.white),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  titulek,
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                naskenovano ? 'NASKENOVÁNO · SPZ' : 'ZADÁNO RUČNĚ',
                style: AppTextStyles.monoLabel.copyWith(
                  color: palette.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.base),
          _Karta(zakazka: zakazka),
          if (sTlacitky) ...[
            const SizedBox(height: Insets.base),
            TlacitkaIdentifikace(
              zakazka: zakazka,
              onZahajit: onZahajit,
              onNeniToOno: onNeniToOno,
            ),
          ],
        ],
      ),
    );
  }
}

/// „Není to ono" a „Zahájit příjem" - pod kartou, nebo na tabletu svisle
/// u kraje obrazovky.
///
/// Řídí se nastavením spouště fotoaparátu: kdo má spoušť vlevo, drží
/// zařízení levou rukou, takže i hlavní tlačítko patří vlevo.
class TlacitkaIdentifikace extends ConsumerWidget {
  const TlacitkaIdentifikace({
    super.key,
    required this.zakazka,
    required this.onZahajit,
    this.onNeniToOno,
    this.svisle = false,
  });

  final ServiceOrder zakazka;
  final VoidCallback onZahajit;
  final VoidCallback? onNeniToOno;

  /// Pod sebou - v postranním sloupci u kraje obrazovky.
  final bool svisle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prijem = ref.watch(prijemZakazkyProvider(zakazka.id)).valueOrNull;
    final vlevo = ref.watch(nastaveniProvider).spoust == UmisteniSpouste.vlevo;
    final akce = switch (prijem?.stav ?? StavPrijmu.nezahajen) {
      StavPrijmu.nezahajen => 'Zahájit příjem · fotodokumentace',
      StavPrijmu.rozpracovany => 'Pokračovat v příjmu',
      StavPrijmu.dokoncen => 'Zobrazit příjem',
    };

    final zahajit = FilledButton(
      key: Key('zahajit-prijem-${zakazka.id}'),
      onPressed: onZahajit,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      ),
      child: Text(
        akce,
        textAlign: TextAlign.center,
        style: AppTextStyles.buttonLabel,
      ),
    );
    final neniToOno = onNeniToOno == null
        ? null
        : OutlinedButton(
            key: const Key('neni-to-ono'),
            onPressed: onNeniToOno,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.hairline2),
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            ),
            child: const Text('Není to ono'),
          );

    if (svisle) {
      // Velká plocha pod palcem, „Není to ono" menší pod ní.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 112, child: zahajit),
          if (neniToOno != null) ...[
            const SizedBox(height: Insets.md),
            SizedBox(height: Sizes.ctaHeight, child: neniToOno),
          ],
        ],
      );
    }

    // Hlavní tlačítko na straně palce.
    final radek = [
      if (neniToOno != null) ...[
        SizedBox(height: Sizes.ctaHeight, child: neniToOno),
        const SizedBox(width: Insets.md),
      ],
      Expanded(
        child: SizedBox(height: Sizes.ctaHeight, child: zahajit),
      ),
    ];
    return Row(children: vlevo ? radek.reversed.toList() : radek);
  }
}

class _Karta extends StatelessWidget {
  const _Karta({required this.zakazka});

  final ServiceOrder zakazka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final z = zakazka;
    final zavady = [
      for (final zavada in z.zavady)
        if ((zavada.nazev ?? zavada.text).trim().isNotEmpty)
          (zavada.nazev ?? zavada.text).trim(),
    ];
    final doplnky = [
      if (z.typZakazky != null) z.typZakazky!.nazev,
      if (z.mechanicName != null) z.mechanicName!,
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: Insets.base,
                  runSpacing: Insets.xxs,
                  children: [
                    Text(
                      z.licensePlate,
                      style: AppTextStyles.plateLarge.copyWith(
                        color: palette.text,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        z.model,
                        style: AppTextStyles.cardModel.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Na telefonu na výšku by se tři sloupce nevešly.
                    final sloupcu = constraints.maxWidth >= 420 ? 3 : 2;
                    final sirka =
                        (constraints.maxWidth - (sloupcu - 1) * Insets.base) /
                        sloupcu;
                    return Wrap(
                      spacing: Insets.base,
                      runSpacing: Insets.base,
                      children: [
                        for (final (popisek, hodnota) in [
                          ('ZAKÁZKA', z.id),
                          ('ZÁKAZNÍK', z.customerName),
                          (
                            'PŘIJATO',
                            z.receivedAt == null
                                ? 'Neuvedeno'
                                : AppDateFormat.date(z.receivedAt!),
                          ),
                        ])
                          SizedBox(
                            width: sirka,
                            child: _Udaj(popisek: popisek, hodnota: hodnota),
                          ),
                      ],
                    );
                  },
                ),
                if (z.vin.isNotEmpty) ...[
                  const SizedBox(height: Insets.base),
                  Row(
                    children: [
                      Text(
                        'VIN',
                        style: AppTextStyles.overline.copyWith(
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Flexible(
                        child: SelectableText(
                          z.vin,
                          style: AppTextStyles.monoLabel.copyWith(
                            color: palette.text,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (zavady.isNotEmpty || doplnky.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.base,
                Insets.xl,
                Insets.base,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (zavady.isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Závady:  ',
                            style: AppTextStyles.metaSmall.copyWith(
                              color: palette.muted,
                            ),
                          ),
                          TextSpan(
                            text: [
                              ...zavady.take(2),
                              if (zavady.length > 2) '+${zavady.length - 2}',
                            ].join(' · '),
                            style: AppTextStyles.cardBody.copyWith(
                              color: palette.text,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (zavady.isNotEmpty && doplnky.isNotEmpty)
                    const SizedBox(height: Insets.xxs),
                  if (doplnky.isNotEmpty)
                    Text(
                      doplnky.join(' · '),
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
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

class _Udaj extends StatelessWidget {
  const _Udaj({required this.popisek, required this.hodnota});

  final String popisek;
  final String hodnota;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          popisek,
          style: AppTextStyles.overline.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 2),
        Text(
          hodnota,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.cardBody.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// „Krok 1 ze 4 · Identifikace vozidla" a čtyři dílky postupu - v hlavičce
/// hledání i v průvodci, ať je vidět, že jde o jeden postup.
class UkazatelKrokuPrijmu extends StatelessWidget {
  const UkazatelKrokuPrijmu({
    super.key,
    required this.cislo,
    required this.nazev,
    this.naTmavem = false,
    this.textKey,
  });

  /// Celkem kroků: identifikace, fotodokumentace, kontrola, souhrn.
  static const celkem = 4;

  final int cislo;
  final String nazev;
  final bool naTmavem;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = naTmavem ? Colors.white70 : AppColors.accent;
    final neaktivni = naTmavem ? Colors.white24 : palette.hairline;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Krok $cislo ze $celkem · $nazev',
            key: textKey,
            style: AppTextStyles.metaSmall.copyWith(
              color: text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        for (var i = 1; i <= celkem; i++) ...[
          Container(
            width: 26,
            height: 4,
            decoration: BoxDecoration(
              color: i <= cislo ? AppColors.accent : neaktivni,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (i < celkem) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
