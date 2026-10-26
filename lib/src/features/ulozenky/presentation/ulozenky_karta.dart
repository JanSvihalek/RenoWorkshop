import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../orders/domain/repositories/service_order_repository.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../../orders/presentation/widgets/detail_cards.dart';
import '../../prijem/domain/entities/dezen.dart';
import '../../prijem/presentation/widgets/dezen_pneu.dart';
import '../data/ulozenky_data_source.dart';
import '../domain/ulozenka_pneu.dart';

/// Uloženky vozu zakázky. Zdroj bez uloženek (starší služba) vrátí prázdno.
final ulozenkyZakazkyProvider = FutureProvider.autoDispose
    .family<List<UlozenkaPneu>, String>((ref, orderId) async {
      final zdroj = ref.watch(serviceOrderDataSourceProvider);
      if (zdroj is! UlozenkyDataSource) return const [];
      try {
        return await (zdroj as UlozenkyDataSource).ulozenkyZakazky(orderId);
      } on ServiceOrderException {
        rethrow;
      } catch (chyba) {
        throw ServiceOrderException('Uloženky se nepodařilo načíst: $chyba');
      }
    });

/// Karta Uloženky pneu v detailu zakázky - načte si je sama.
class UlozenkyZakazkyKarta extends ConsumerWidget {
  const UlozenkyZakazkyKarta({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ulozenky = ref.watch(ulozenkyZakazkyProvider(orderId));
    return UlozenkyPneuKarta(
      ulozenky: ulozenky.valueOrNull,
      chyba: ulozenky.hasError && !ulozenky.hasValue,
      onZnovu: () => ref.invalidate(ulozenkyZakazkyProvider(orderId)),
    );
  }
}

/// Uloženky pneu - aktivní nahoře, ukončené a zrušené pod rozbalením.
/// Detail zakázky i karta vozu.
class UlozenkyPneuKarta extends StatefulWidget {
  const UlozenkyPneuKarta({
    super.key,
    required this.ulozenky,
    this.chyba = false,
    this.onZnovu,
  });

  /// `null` = načítá se.
  final List<UlozenkaPneu>? ulozenky;
  final bool chyba;
  final VoidCallback? onZnovu;

  @override
  State<UlozenkyPneuKarta> createState() => _UlozenkyPneuKartaState();
}

class _UlozenkyPneuKartaState extends State<UlozenkyPneuKarta> {
  bool _starsi = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final vse = widget.ulozenky;
    final aktivni = [...?vse?.where((u) => u.aktivni)];
    final starsi = [...?vse?.where((u) => !u.aktivni)];

    Widget text(String t) =>
        Text(t, style: AppTextStyles.cardBody.copyWith(color: palette.muted));

    return DetailCard(
      key: const Key('ulozenky-pneu'),
      zHeliosu: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  aktivni.isEmpty
                      ? 'ULOŽENKY PNEU'
                      : 'ULOŽENKY PNEU  ${aktivni.length}',
                  barva: AppColors.heliosZelena(context),
                ),
              ),
              const HeliosZnacka(text: 'JEN KE ČTENÍ'),
            ],
          ),
          const SizedBox(height: Insets.sm),
          if (widget.chyba)
            Row(
              children: [
                Expanded(child: text('Uloženky se nepodařilo načíst.')),
                if (widget.onZnovu != null)
                  TextButton(
                    onPressed: widget.onZnovu,
                    child: const Text('Znovu'),
                  ),
              ],
            )
          else if (vse == null)
            text('Načítám uloženky…')
          else if (vse.isEmpty)
            text('Vůz u nás nemá žádnou uloženku pneu.')
          else ...[
            _Dlazdice(ulozenky: aktivni),
            if (starsi.isNotEmpty) ...[
              TextButton.icon(
                key: const Key('ulozenky-starsi'),
                onPressed: () => setState(() => _starsi = !_starsi),
                icon: Icon(
                  _starsi
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text('Ukončené a zrušené (${starsi.length})'),
              ),
              if (_starsi)
                Opacity(opacity: 0.7, child: _Dlazdice(ulozenky: starsi)),
            ],
          ],
        ],
      ),
    );
  }
}

/// Uloženky jako dlaždice - na širší kartě dvě vedle sebe.
class _Dlazdice extends StatelessWidget {
  const _Dlazdice({required this.ulozenky});

  final List<UlozenkaPneu> ulozenky;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vedleSebe = constraints.maxWidth >= 480;
        final sirka = vedleSebe
            ? (constraints.maxWidth - Insets.md) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: [
            for (final u in ulozenky)
              SizedBox(
                width: sirka,
                child: _Ulozenka(ulozenka: u),
              ),
          ],
        );
      },
    );
  }
}

/// Jedna uloženka: číslo, sezóna a stav, pneu, údaje a kola s dezénem.
class _Ulozenka extends StatelessWidget {
  const _Ulozenka({required this.ulozenka});

  final UlozenkaPneu ulozenka;

  static const _poradiKol = ['LP', 'LZ', 'PP', 'PZ', 'Rezerva'];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final u = ulozenka;
    final prvni = u.kola.firstOrNull;
    final udaje = [
      ?prvni?.rozmer,
      if (prvni?.dot != null) 'DOT ${prvni!.dot}',
      if (u.ulozeno != null) 'uloženo ${AppDateFormat.date(u.ulozeno!)}',
      if (u.pocet != null) '${u.pocet} ks',
      ?u.umisteni,
      if (u.vraceno != null)
        'vráceno ${AppDateFormat.date(u.vraceno!)}'
      else if (u.vratitDo != null)
        'vrátit ${AppDateFormat.date(u.vratitDo!)}',
    ];
    final pravidla = Dezen(zimni: u.zimni ?? false);
    final kola = {for (final k in u.kola) k.pozice: k};

    return Container(
      key: Key('ulozenka-${u.cislo}'),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                u.cislo,
                style: AppTextStyles.cardBody.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (u.zimni != null)
                _Stitek(
                  u.zimni! ? 'Zimní' : 'Letní',
                  barva: u.zimni! ? AppColors.accent : const Color(0xFFC98200),
                ),
              if (u.stav != null) _Stitek(u.stav!, barva: palette.muted),
              if (u.zTetoZakazky)
                const _Stitek('Z této zakázky', barva: AppColors.readyGreen),
            ],
          ),
          if (prvni != null && prvni.pneu.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(
              prvni.pneu,
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (udaje.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              udaje.join(' · '),
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
          ],
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              for (final (i, pozice) in _poradiKol.indexed) ...[
                if (i > 0) const SizedBox(width: Insets.xs),
                Expanded(
                  child: _Kolo(
                    nazev: pozice == 'Rezerva' ? 'Rez.' : pozice,
                    dezen: kola[pozice]?.dezen,
                    barva: kola[pozice]?.dezen == null
                        ? palette.muted
                        : barvaDezenu(
                            pravidla.stavKola(kola[pozice]!.dezen!),
                            palette,
                          ),
                  ),
                ),
              ],
            ],
          ),
          if (u.poznamka != null) ...[
            const SizedBox(height: Insets.xs),
            Text(
              u.poznamka!,
              style: AppTextStyles.metaSmall.copyWith(
                color: palette.text,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kolo uloženky - pozice a dezén v mm.
class _Kolo extends StatelessWidget {
  const _Kolo({required this.nazev, required this.dezen, required this.barva});

  final String nazev;
  final double? dezen;
  final Color barva;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Column(
        children: [
          Text(
            nazev,
            style: AppTextStyles.metaSmall.copyWith(
              fontSize: 11,
              color: palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            dezen == null ? '–' : formatMm(dezen!),
            style: AppTextStyles.cardBody.copyWith(
              color: barva,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dezen != null)
            Text(
              'mm',
              style: AppTextStyles.metaSmall.copyWith(
                fontSize: 10,
                color: palette.muted,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stitek extends StatelessWidget {
  const _Stitek(this.text, {required this.barva});

  final String text;
  final Color barva;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: barva.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTextStyles.metaSmall.copyWith(
          color: barva,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
