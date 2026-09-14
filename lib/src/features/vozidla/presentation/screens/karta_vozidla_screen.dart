import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../orders/domain/entities/service_order.dart';
import '../../../orders/presentation/widgets/detail_cards.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../domain/entities/vozidlo.dart';
import '../controllers/vozidla_providers.dart';

/// Karta vozidla: vůz, majitel, kontaktní osoba a všechny zakázky.
///
/// Zakázky jsou rozdělané i ukončené, od nejnovější - tatáž karta jako
/// v seznamu dílny, takže stav z Heliosu a dílenský stav jsou vidět hned.
class KartaVozidlaScreen extends ConsumerWidget {
  const KartaVozidlaScreen({
    super.key,
    required this.vozidloId,
    required this.onBack,
    required this.onOpenOrder,
    this.zobrazitZpet = true,
  });

  final int vozidloId;
  final VoidCallback onBack;

  /// Otevře detail zakázky a počká na návrat - karta se pak načte znovu,
  /// ať je vidět stav, který mezitím někdo přidal.
  final Future<void> Function(ServiceOrder order) onOpenOrder;

  /// Na tabletu je karta vedle výsledků hledání, není kam se vracet.
  final bool zobrazitZpet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final karta = ref.watch(kartaVozidlaProvider(vozidloId));

    return Scaffold(
      backgroundColor: palette.background,
      body: karta.when(
        loading: () => Column(
          children: [
            _Hlavicka(onBack: onBack, zobrazitZpet: zobrazitZpet),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
        error: (chyba, _) => Column(
          children: [
            _Hlavicka(onBack: onBack, zobrazitZpet: zobrazitZpet),
            Expanded(child: _Sdeleni('$chyba')),
          ],
        ),
        data: (vozidlo) {
          if (vozidlo == null) {
            return Column(
              children: [
                _Hlavicka(onBack: onBack, zobrazitZpet: zobrazitZpet),
                const Expanded(child: _Sdeleni('Vozidlo nebylo nalezeno.')),
              ],
            );
          }

          return Column(
            children: [
              _Hlavicka(
                onBack: onBack,
                zobrazitZpet: zobrazitZpet,
                spz: vozidlo.spz,
                model: vozidlo.model,
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: () async =>
                      ref.invalidate(kartaVozidlaProvider(vozidloId)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xl,
                      Insets.lg,
                      Insets.xl,
                      Insets.giant,
                    ),
                    children: [
                      const SectionLabel('VOZIDLO'),
                      const SizedBox(height: Insets.sm),
                      _KartaVozu(vozidlo: vozidlo),
                      const SizedBox(height: Insets.xl),
                      const SectionLabel('MAJITEL'),
                      const SizedBox(height: Insets.sm),
                      if (vozidlo.majitel case final majitel?)
                        _KartaMajitele(majitel: majitel)
                      else
                        const _Prazdne('Majitel není v Heliosu uvedený.'),
                      if (vozidlo.kontakt case final kontakt?) ...[
                        const SizedBox(height: Insets.xl),
                        const SectionLabel('KONTAKTNÍ OSOBA'),
                        const SizedBox(height: Insets.sm),
                        _KartaKontaktu(kontakt: kontakt),
                      ],
                      const SizedBox(height: Insets.xl),
                      SectionLabel('ZAKÁZKY (${vozidlo.zakazky.length})'),
                      const SizedBox(height: Insets.sm),
                      if (vozidlo.zakazky.isEmpty)
                        const _Prazdne('Vůz u nás zatím nemá žádnou zakázku.')
                      else
                        for (final zakazka in vozidlo.zakazky) ...[
                          OrderCard(
                            order: zakazka,
                            onTap: () async {
                              await onOpenOrder(zakazka);
                              ref.invalidate(kartaVozidlaProvider(vozidloId));
                            },
                          ),
                          const SizedBox(height: Insets.md),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Hlavicka extends StatelessWidget {
  const _Hlavicka({
    required this.onBack,
    required this.zobrazitZpet,
    this.spz,
    this.model,
  });

  final VoidCallback onBack;
  final bool zobrazitZpet;
  final String? spz;
  final String? model;

  @override
  Widget build(BuildContext context) {
    final isIOS = context.isIOS;

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        zobrazitZpet ? Insets.base : Insets.xxl,
        MediaQuery.paddingOf(context).top + Insets.base,
        Insets.xxl,
        Insets.xl,
      ),
      child: Row(
        children: [
          if (zobrazitZpet) ...[
            IconButton(
              tooltip: 'Zpět',
              onPressed: onBack,
              icon: Icon(
                isIOS
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_back_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: Insets.xxs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (spz == null || spz!.isEmpty) ? 'Vozidlo' : spz!,
                  style: AppTextStyles.plateLarge.copyWith(color: Colors.white),
                ),
                if (model != null && model!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    model!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.appBarMeta.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KartaVozu extends StatelessWidget {
  const _KartaVozu({required this.vozidlo});

  final KartaVozidla vozidlo;

  @override
  Widget build(BuildContext context) {
    final tachometr = vozidlo.tachometr;
    final prodano = vozidlo.prodano;

    return DetailCard(
      child: Column(
        children: [
          _Udaj('VIN', vozidlo.vin, pismo: _Pismo.mono),
          _Udaj('Model', vozidlo.model),
          _Udaj('Série', vozidlo.serie),
          _Udaj('Palivo', vozidlo.palivo),
          _Udaj('Motor', vozidlo.motor),
          _Udaj(
            'Tachometr',
            tachometr == null
                ? null
                : '${NumberFormat.decimalPattern('cs_CZ').format(tachometr)} km',
          ),
          _Udaj(
            'Prodáno',
            prodano == null ? null : AppDateFormat.date(prodano),
          ),
        ],
      ),
    );
  }
}

class _KartaMajitele extends StatelessWidget {
  const _KartaMajitele({required this.majitel});

  final MajitelVozidla majitel;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      child: Column(
        children: [
          _Udaj('Název', majitel.nazev, pismo: _Pismo.tucne),
          _Udaj('Číslo zákazníka', majitel.cisloZakaznika),
          _Udaj('IČO', majitel.ico),
          _Udaj('DIČ', majitel.dic),
          _Udaj('Adresa', majitel.adresa),
          _Udaj('Telefon', majitel.telefon),
          _Udaj('E-mail', majitel.email),
        ],
      ),
    );
  }
}

class _KartaKontaktu extends StatelessWidget {
  const _KartaKontaktu({required this.kontakt});

  final KontaktVozidla kontakt;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      child: Column(
        children: [
          _Udaj('Jméno', kontakt.jmeno, pismo: _Pismo.tucne),
          _Udaj('Telefon', kontakt.telefon),
          _Udaj('E-mail', kontakt.email),
        ],
      ),
    );
  }
}

enum _Pismo { bezne, tucne, mono }

/// Řádek údaje. Prázdný údaj se vynechá - karta z Heliosu bývá děravá
/// a řada pomlček by jen zabírala místo.
///
/// Hodnotu jde označit a zkopírovat: telefon nebo VIN se z karty
/// přepisuje do jiných systémů.
class _Udaj extends StatelessWidget {
  const _Udaj(this.popisek, this.hodnota, {this.pismo = _Pismo.bezne});

  final String popisek;
  final String? hodnota;
  final _Pismo pismo;

  @override
  Widget build(BuildContext context) {
    final text = hodnota;
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();

    final palette = context.palette;
    final zaklad = switch (pismo) {
      _Pismo.mono => AppTextStyles.monoLabel.copyWith(fontSize: 13.5),
      _Pismo.tucne => AppTextStyles.cardModel,
      _Pismo.bezne => AppTextStyles.cardBody,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              popisek,
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              text,
              style: zaklad.copyWith(color: palette.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _Prazdne extends StatelessWidget {
  const _Prazdne(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      child: Text(
        text,
        style: AppTextStyles.cardBody.copyWith(color: context.palette.muted),
      ),
    );
  }
}

class _Sdeleni extends StatelessWidget {
  const _Sdeleni(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.giant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: palette.muted),
            const SizedBox(height: Insets.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
