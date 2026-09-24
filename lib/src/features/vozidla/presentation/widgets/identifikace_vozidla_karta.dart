import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/vozidlo.dart';

/// Nalezený vůz se vším, co o něm víme z Heliosu - stejná karta jako
/// identifikace v příjmu, ať technik hned vidí, že je to ten vůz, a nemusí
/// kvůli motoru nebo telefonu na majitele nic dalšího otevírat.
class IdentifikaceVozidlaKarta extends StatelessWidget {
  const IdentifikaceVozidlaKarta({
    super.key,
    required this.vozidlo,
    required this.naskenovano,
    this.onNeniToOno,
  });

  final KartaVozidla vozidlo;

  /// Hledání přišlo ze skeneru, ne z klávesnice - jen do popisku.
  final bool naskenovano;

  /// `null` tlačítko schová.
  final VoidCallback? onNeniToOno;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
                  'Nalezeno vozidlo · ${_zakazek(vozidlo.zakazky.length)}',
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
          _Karta(vozidlo: vozidlo),
          if (onNeniToOno != null) ...[
            const SizedBox(height: Insets.base),
            SizedBox(
              height: Sizes.ctaHeight,
              child: OutlinedButton(
                key: const Key('neni-to-ono'),
                onPressed: onNeniToOno,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.text,
                  side: BorderSide(color: palette.hairline2),
                ),
                child: const Text('Není to ono - skenovat znovu'),
              ),
            ),
          ],
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
  const _Karta({required this.vozidlo});

  final KartaVozidla vozidlo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final v = vozidlo;
    final tachometr = v.tachometr;
    final registrace = v.prodano;
    final majitel = v.majitel;
    final kontakt = v.kontakt;

    // Prázdné údaje se vynechají - karta z Heliosu bývá děravá.
    final udaje = [
      ('SÉRIE', v.serie),
      ('PALIVO', v.palivo),
      ('MOTOR', v.motor),
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
                      v.spz.isEmpty ? 'Bez SPZ' : v.spz,
                      style: AppTextStyles.plateLarge.copyWith(
                        color: palette.text,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        v.model.isEmpty ? 'Neznámý model' : v.model,
                        style: AppTextStyles.cardModel.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (v.vin.isNotEmpty) ...[
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
                          v.vin,
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
                  jmeno: majitel?.nazev,
                  radky: [
                    if (majitel != null) ...[
                      [
                        if (majitel.cisloZakaznika case final c?) 'č. $c',
                        if (majitel.ico case final ico?) 'IČO $ico',
                        if (majitel.dic case final dic?) 'DIČ $dic',
                      ].join(' · '),
                      majitel.adresa,
                      majitel.telefon,
                      majitel.email,
                    ],
                  ],
                  prazdne: 'Není v Heliosu uvedený',
                ),
                if (kontakt != null)
                  _Osoba(
                    popisek: 'KONTAKTNÍ OSOBA',
                    jmeno: kontakt.jmeno,
                    radky: [kontakt.telefon, kontakt.email],
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
    this.prazdne = '',
  });

  final String popisek;
  final String? jmeno;
  final List<String?> radky;

  /// Co ukázat, když jméno chybí.
  final String prazdne;

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
        SelectableText(
          nazev.isEmpty ? prazdne : nazev,
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
