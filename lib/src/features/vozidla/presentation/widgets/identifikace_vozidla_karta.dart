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
                const SizedBox(height: Insets.lg),
                _Oddil(
                  udaje: [
                    ('VIN', v.vin, mono: true),
                    ('MODEL', v.model, mono: false),
                    ('SÉRIE', v.serie, mono: false),
                    ('PALIVO', v.palivo, mono: false),
                    ('MOTOR', v.motor, mono: false),
                    (
                      'TACHOMETR',
                      tachometr == null
                          ? null
                          : '${NumberFormat.decimalPattern('cs_CZ').format(tachometr)} km',
                      mono: false,
                    ),
                    // `prodej_datum` z Heliosu - na dílně se mu říká datum
                    // registrace.
                    (
                      'DATUM REGISTRACE',
                      registrace == null
                          ? null
                          : AppDateFormat.date(registrace),
                      mono: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Sekce(
            nadpis: 'MAJITEL',
            child: majitel == null
                ? Text(
                    'Majitel není v Heliosu uvedený.',
                    style: AppTextStyles.cardBody.copyWith(
                      color: palette.muted,
                    ),
                  )
                : _Oddil(
                    udaje: [
                      ('NÁZEV', majitel.nazev, mono: false),
                      ('ČÍSLO ZÁKAZNÍKA', majitel.cisloZakaznika, mono: false),
                      ('IČO', majitel.ico, mono: false),
                      ('DIČ', majitel.dic, mono: false),
                      ('ADRESA', majitel.adresa, mono: false),
                      ('TELEFON', majitel.telefon, mono: false),
                      ('E-MAIL', majitel.email, mono: false),
                    ],
                  ),
          ),
          if (kontakt != null)
            _Sekce(
              nadpis: 'KONTAKTNÍ OSOBA',
              child: _Oddil(
                udaje: [
                  ('JMÉNO', kontakt.jmeno, mono: false),
                  ('TELEFON', kontakt.telefon, mono: false),
                  ('E-MAIL', kontakt.email, mono: false),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Oddíl karty pod čarou - majitel, kontaktní osoba.
class _Sekce extends StatelessWidget {
  const _Sekce({required this.nadpis, required this.child});

  final String nadpis;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nadpis,
            style: AppTextStyles.sectionTitle.copyWith(
              color: palette.text,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}

/// Údaje s popisky v mřížce - na telefonu na výšku dva sloupce, jinak tři.
///
/// Prázdný údaj se vynechá - karta z Heliosu bývá děravá a řada pomlček
/// by jen zabírala místo.
class _Oddil extends StatelessWidget {
  const _Oddil({required this.udaje});

  final List<(String, String?, {bool mono})> udaje;

  @override
  Widget build(BuildContext context) {
    final vyplnene = [
      for (final (popisek, hodnota, :mono) in udaje)
        if (hodnota != null && hodnota.trim().isNotEmpty)
          (popisek, hodnota.trim(), mono),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final sloupcu = constraints.maxWidth >= 420 ? 3 : 2;
        final sirka =
            (constraints.maxWidth - (sloupcu - 1) * Insets.base) / sloupcu;
        return Wrap(
          spacing: Insets.base,
          runSpacing: Insets.base,
          children: [
            for (final (popisek, hodnota, mono) in vyplnene)
              SizedBox(
                // Dlouhé hodnoty (VIN, adresa, e-mail) přes celý řádek,
                // ve sloupečku by se lámaly.
                width: _siroky(popisek) ? constraints.maxWidth : sirka,
                child: _Udaj(popisek: popisek, hodnota: hodnota, mono: mono),
              ),
          ],
        );
      },
    );
  }

  static bool _siroky(String popisek) =>
      const {'VIN', 'MODEL', 'NÁZEV', 'ADRESA', 'E-MAIL'}.contains(popisek);
}

/// Hodnotu jde označit a zkopírovat: telefon nebo VIN se z karty
/// přepisuje do jiných systémů.
class _Udaj extends StatelessWidget {
  const _Udaj({
    required this.popisek,
    required this.hodnota,
    required this.mono,
  });

  final String popisek;
  final String hodnota;
  final bool mono;

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
        SelectableText(
          hodnota,
          style: mono
              ? AppTextStyles.monoLabel.copyWith(
                  color: palette.text,
                  fontSize: 13.5,
                  letterSpacing: 0.6,
                )
              : AppTextStyles.cardBody.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}
