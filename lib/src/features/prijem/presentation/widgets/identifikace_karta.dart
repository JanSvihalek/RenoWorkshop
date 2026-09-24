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
///
/// Vedle karty je „Další krok" s velkou dlaždicí na zahájení. Na straně
/// podle nastavení spouště fotoaparátu - kdo má spoušť vpravo, drží
/// zařízení pravou rukou a dlaždice má být pod palcem. Kde se vedle karty
/// nevejde (telefon) nebo je spoušť dole, je pod kartou.
class IdentifikaceKarta extends ConsumerWidget {
  const IdentifikaceKarta({
    super.key,
    required this.zakazka,
    required this.naskenovano,
    required this.onZahajit,
    this.onNeniToOno,
  });

  final ServiceOrder zakazka;

  /// Hledání přišlo ze skeneru, ne z klávesnice - jen do popisku.
  final bool naskenovano;
  final VoidCallback onZahajit;

  /// `null` tlačítko schová - u výběru z víc zakázek není kam „jinam".
  final VoidCallback? onNeniToOno;

  /// Šířka samotné karty a panelu vedle ní.
  static const sirkaKarty = 580.0;
  static const sirkaPanelu = 300.0;
  static const _mezera = Insets.huge;

  /// Od téhle šířky se panel vejde vedle karty (karta se může trochu
  /// zúžit).
  static const sirkaProPanelVedle = 760.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prijem = ref.watch(prijemZakazkyProvider(zakazka.id)).valueOrNull;
    final stav = prijem?.stav ?? StavPrijmu.nezahajen;
    final spoust = ref.watch(nastaveniProvider).spoust;

    final (String titulek, IconData ikona, Color barva) = switch (stav) {
      StavPrijmu.nezahajen => (
        'Nalezena otevřená zakázka',
        Icons.check_rounded,
        AppColors.readyGreen,
      ),
      StavPrijmu.rozpracovany => (
        'Příjem rozpracovaný',
        Icons.pending_actions_rounded,
        AppColors.repairBlue,
      ),
      StavPrijmu.dokoncen => (
        'Příjem dokončen',
        Icons.task_alt_rounded,
        AppColors.readyGreen,
      ),
    };

    final karta = Column(
      key: Key('karta-${zakazka.id}'),
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
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: sirkaKarty + _mezera + sirkaPanelu,
      ),
      child: LayoutBuilder(
        key: Key('identifikace-${zakazka.id}'),
        builder: (context, constraints) {
          final vedle =
              spoust != UmisteniSpouste.dole &&
              constraints.maxWidth >= sirkaProPanelVedle;

          if (vedle) {
            final panel = SizedBox(
              key: const Key('dalsi-krok-vedle'),
              width: sirkaPanelu,
              child: _DalsiKrok(
                prijem: prijem,
                zakazka: zakazka,
                onZahajit: onZahajit,
                onNeniToOno: onNeniToOno,
                svisle: true,
              ),
            );
            final vlevo = spoust == UmisteniSpouste.vlevo;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vlevo) ...[panel, const SizedBox(width: _mezera)],
                Expanded(child: karta),
                if (!vlevo) ...[const SizedBox(width: _mezera), panel],
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: sirkaKarty),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  karta,
                  const SizedBox(height: Insets.xl),
                  _DalsiKrok(
                    prijem: prijem,
                    zakazka: zakazka,
                    onZahajit: onZahajit,
                    onNeniToOno: onNeniToOno,
                    svisle: false,
                    vlevo: spoust == UmisteniSpouste.vlevo,
                    dole: spoust == UmisteniSpouste.dole,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// „Další krok" - co příjem čeká, velká dlaždice na zahájení a „Není to
/// ono".
class _DalsiKrok extends StatelessWidget {
  const _DalsiKrok({
    required this.prijem,
    required this.zakazka,
    required this.onZahajit,
    required this.onNeniToOno,
    required this.svisle,
    this.vlevo = false,
    this.dole = false,
  });

  final Prijem? prijem;
  final ServiceOrder zakazka;
  final VoidCallback onZahajit;
  final VoidCallback? onNeniToOno;

  /// Panel vedle karty: popis, dlaždice a „Není to ono" pod sebou.
  final bool svisle;

  /// Pod kartou: dlaždice vlevo (spoušť vlevo), nebo přes celou šířku
  /// s „Není to ono" pod ní (spoušť dole).
  final bool vlevo;
  final bool dole;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = prijem;

    final (
      String nadpis,
      String krok,
      String popis,
      IconData ikona,
      String akce,
    ) = switch (p?.stav ?? StavPrijmu.nezahajen) {
      StavPrijmu.nezahajen => (
        'DALŠÍ KROK',
        'Fotodokumentace',
        'Krok 2 ze 4 · exteriér, interiér, tachometr',
        Icons.photo_camera_outlined,
        'Zahájit příjem',
      ),
      StavPrijmu.rozpracovany => (
        'ROZPRACOVANÝ PŘÍJEM',
        'Kontrola vozidla',
        'Zkontrolováno ${p!.pocetVyplnenych} z ${p.pocetPovinnych}',
        Icons.play_arrow_rounded,
        'Pokračovat v příjmu',
      ),
      StavPrijmu.dokoncen => (
        'PŘÍJEM DOKONČEN',
        'Souhrn příjmu',
        [
          if (p!.dokoncenoAt != null) AppDateFormat.date(p.dokoncenoAt!),
          ?p.dokoncilKdo,
        ].join(' · '),
        Icons.task_alt_rounded,
        'Zobrazit příjem',
      ),
    };

    final dlazdice = _Dlazdice(
      key: Key('zahajit-prijem-${zakazka.id}'),
      ikona: ikona,
      text: akce,
      svisle: svisle,
      onTap: onZahajit,
    );
    final neniToOno = onNeniToOno == null
        ? null
        : OutlinedButton(
            key: const Key('neni-to-ono'),
            onPressed: onNeniToOno,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.hairline2),
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              textStyle: AppTextStyles.buttonLabel,
            ),
            child: const Text('Není to ono', textAlign: TextAlign.center),
          );

    final Widget tlacitka;
    if (svisle || dole || neniToOno == null) {
      tlacitka = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dlazdice,
          if (neniToOno != null) ...[
            const SizedBox(height: Insets.md),
            SizedBox(height: Sizes.ctaHeight, child: neniToOno),
          ],
        ],
      );
    } else {
      // Na telefonu vedle sebe, dlaždice na straně palce.
      final radek = [
        Expanded(child: dlazdice),
        const SizedBox(width: Insets.md),
        SizedBox(width: 116, height: _Dlazdice.vyskaVedle, child: neniToOno),
      ];
      tlacitka = Row(children: vlevo ? radek : radek.reversed.toList());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          nadpis,
          style: AppTextStyles.overline.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Insets.xxs),
        Text(
          krok,
          style: AppTextStyles.sectionTitle.copyWith(color: palette.text),
        ),
        if (popis.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            popis,
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ],
        const SizedBox(height: Insets.base),
        tlacitka,
      ],
    );
  }
}

/// Velká modrá plocha - trefí se do ní i palec v rukavici.
///
/// V panelu vedle karty vysoká s ikonou nahoře a popiskem dole, pod kartou
/// nižší s ikonou vedle popisku.
class _Dlazdice extends StatelessWidget {
  const _Dlazdice({
    super.key,
    required this.ikona,
    required this.text,
    required this.svisle,
    required this.onTap,
  });

  static const vyskaSvisle = 132.0;
  static const vyskaVedle = 80.0;

  final IconData ikona;
  final String text;
  final bool svisle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Dlouhý popisek („Pokračovat v příjmu") na úzké dlaždici se zmenší,
    // místo aby přetekl.
    final popisek = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.primary,
          fontSize: 18,
        ),
      ),
    );

    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: svisle ? vyskaSvisle : vyskaVedle,
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: svisle
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(ikona, size: 28, color: AppColors.primary),
                        Flexible(child: popisek),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(ikona, size: 28, color: AppColors.primary),
                        const SizedBox(width: Insets.base),
                        Expanded(child: popisek),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
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
