import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/vozidlo.dart';
import '../controllers/vozidla_providers.dart';

/// Nalezený vůz se vším, co o něm víme z Heliosu - stejná karta jako
/// identifikace v příjmu, ať technik nemusí kvůli motoru nebo telefonu
/// na majitele otevírat další obrazovku.
///
/// Hledání vrací jen SPZ, VIN, model a majitele. Zbytek se dočte z karty
/// vozidla; do té doby je vidět aspoň to, co přišlo z hledání.
class IdentifikaceVozidlaKarta extends ConsumerWidget {
  const IdentifikaceVozidlaKarta({
    super.key,
    required this.vozidlo,
    required this.naskenovano,
    required this.onOtevrit,
    this.onNeniToOno,
    this.jeVybrane = false,
  });

  final NalezeneVozidlo vozidlo;

  /// Hledání přišlo ze skeneru, ne z klávesnice - jen do popisku.
  final bool naskenovano;
  final VoidCallback onOtevrit;

  /// `null` tlačítko schová - u výběru z víc vozidel není kam „jinam".
  final VoidCallback? onNeniToOno;

  /// Na tabletu je karta vozidla se zakázkami vpravo - otevřený vůz musí
  /// být poznat.
  final bool jeVybrane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final karta = ref.watch(kartaVozidlaProvider(vozidlo.id));
    final pocet = vozidlo.pocetZakazek;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: Column(
        key: Key('identifikace-vozidla-${vozidlo.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.readyGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  'Nalezeno vozidlo · ${_zakazek(pocet)}',
                  style: AppTextStyles.cardBody.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                naskenovano ? 'NASKENOVÁNO' : 'ZADÁNO RUČNĚ',
                style: AppTextStyles.monoLabel.copyWith(
                  color: palette.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.base),
          _Karta(vozidlo: vozidlo, karta: karta, jeVybrane: jeVybrane),
          const SizedBox(height: Insets.base),
          Row(
            children: [
              if (onNeniToOno != null) ...[
                SizedBox(
                  height: Sizes.ctaHeight,
                  child: OutlinedButton(
                    key: const Key('neni-to-ono'),
                    onPressed: onNeniToOno,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.text,
                      side: BorderSide(color: palette.hairline2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.xl,
                      ),
                    ),
                    child: const Text('Není to ono'),
                  ),
                ),
                const SizedBox(width: Insets.md),
              ],
              Expanded(
                child: SizedBox(
                  height: Sizes.ctaHeight,
                  child: FilledButton(
                    key: Key('otevrit-vozidlo-${vozidlo.id}'),
                    onPressed: onOtevrit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      pocet == 0
                          ? 'Otevřít kartu vozidla'
                          : 'Zakázky vozidla ($pocet)',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.buttonLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _zakazek(int pocet) => switch (pocet) {
    0 => 'bez zakázek',
    1 => '1 zakázka',
    >= 2 && <= 4 => '$pocet zakázky',
    _ => '$pocet zakázek',
  };
}

class _Karta extends StatelessWidget {
  const _Karta({
    required this.vozidlo,
    required this.karta,
    required this.jeVybrane,
  });

  final NalezeneVozidlo vozidlo;
  final AsyncValue<KartaVozidla?> karta;
  final bool jeVybrane;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final detail = karta.valueOrNull;
    final model = (detail?.model ?? vozidlo.model).trim();
    final vin = (detail?.vin ?? vozidlo.vin).trim();
    final tachometr = detail?.tachometr;
    final registrace = detail?.prodano;

    final udaje = [
      ('SÉRIE', detail?.serie),
      ('PALIVO', detail?.palivo),
      ('MOTOR', detail?.motor),
      (
        'TACHOMETR',
        tachometr == null
            ? null
            : '${NumberFormat.decimalPattern('cs_CZ').format(tachometr)} km',
      ),
      // `prodej_datum` z Heliosu - na dílně se mu říká datum registrace.
      (
        'DATUM REGISTRACE',
        registrace == null ? null : AppDateFormat.date(registrace),
      ),
    ].where((u) => u.$2 != null && u.$2!.trim().isNotEmpty).toList();

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: jeVybrane ? AppColors.accent : palette.hairline,
          width: jeVybrane ? 2 : 1,
        ),
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
                      vozidlo.spz.isEmpty ? 'Bez SPZ' : vozidlo.spz,
                      style: AppTextStyles.plateLarge.copyWith(
                        color: palette.text,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        model.isEmpty ? 'Neznámý model' : model,
                        style: AppTextStyles.cardModel.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (vin.isNotEmpty) ...[
                  const SizedBox(height: Insets.sm),
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
                          vin,
                          style: AppTextStyles.monoLabel.copyWith(
                            color: palette.text,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (udaje.isNotEmpty) ...[
                  const SizedBox(height: Insets.lg),
                  _Mrizka(
                    children: [
                      for (final (popisek, hodnota) in udaje)
                        _Udaj(popisek: popisek, hodnota: hodnota!),
                    ],
                  ),
                ],
                if (karta.isLoading) ...[
                  const SizedBox(height: Insets.lg),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: Insets.sm),
                      Flexible(
                        child: Text(
                          'Načítám údaje o voze…',
                          style: AppTextStyles.metaSmall.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (karta.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.lg),
                    child: Text(
                      'Podrobnosti o voze se nepodařilo načíst.',
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(Insets.xl),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.hairline)),
            ),
            child: _Mrizka(
              sloupcuNaSiroko: 2,
              children: [
                _Osoba(
                  popisek: 'MAJITEL',
                  jmeno: detail?.majitel?.nazev ?? vozidlo.majitel,
                  radky: [
                    if (detail?.majitel case final m?) ...[
                      [
                        if (m.cisloZakaznika case final c?) 'č. $c',
                        if (m.ico case final ico?) 'IČO $ico',
                        if (m.dic case final dic?) 'DIČ $dic',
                      ].join(' · '),
                      m.adresa,
                      m.telefon,
                      m.email,
                    ],
                  ],
                  prazdne: 'Neuveden',
                ),
                if (detail?.kontakt case final k?)
                  _Osoba(
                    popisek: 'KONTAKTNÍ OSOBA',
                    jmeno: k.jmeno,
                    radky: [k.telefon, k.email],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Údaje vedle sebe - na telefonu na výšku o sloupec míň.
class _Mrizka extends StatelessWidget {
  const _Mrizka({required this.children, this.sloupcuNaSiroko = 3});

  final List<Widget> children;
  final int sloupcuNaSiroko;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Na úzké kartě o sloupec míň - majitel s kontaktem pod sebe.
        final sloupcu = constraints.maxWidth >= 420
            ? sloupcuNaSiroko
            : sloupcuNaSiroko - 1;
        final sirka =
            (constraints.maxWidth - (sloupcu - 1) * Insets.base) / sloupcu;
        return Wrap(
          spacing: Insets.base,
          runSpacing: Insets.base,
          children: [
            for (final dite in children) SizedBox(width: sirka, child: dite),
          ],
        );
      },
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

/// Majitel nebo kontaktní osoba. Telefon a e-mail jdou označit
/// a zkopírovat - přepisují se do jiných systémů.
class _Osoba extends StatelessWidget {
  const _Osoba({
    required this.popisek,
    required this.jmeno,
    required this.radky,
    this.prazdne,
  });

  final String popisek;
  final String? jmeno;
  final List<String?> radky;

  /// Co ukázat, když jméno chybí. `null` - ani popisek.
  final String? prazdne;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = [
      for (final r in radky)
        if (r != null && r.trim().isNotEmpty) r.trim(),
    ];
    final nazev = jmeno?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          popisek,
          style: AppTextStyles.overline.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 2),
        Text(
          nazev.isEmpty ? (prazdne ?? '') : nazev,
          style: AppTextStyles.cardBody.copyWith(
            color: nazev.isEmpty ? palette.muted : palette.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final radek in text)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SelectableText(
              radek,
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
          ),
      ],
    );
  }
}
