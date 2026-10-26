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
                  'ULOŽENKY PNEU',
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
            for (final (i, u) in aktivni.indexed) ...[
              if (i > 0) Divider(color: palette.hairline),
              _Ulozenka(ulozenka: u),
            ],
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
                for (final u in starsi)
                  Opacity(opacity: 0.7, child: _Ulozenka(ulozenka: u)),
            ],
          ],
        ],
      ),
    );
  }
}

class _Ulozenka extends StatelessWidget {
  const _Ulozenka({required this.ulozenka});

  final UlozenkaPneu ulozenka;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final u = ulozenka;
    final udaje = [
      if (u.ulozeno != null) 'uloženo ${AppDateFormat.date(u.ulozeno!)}',
      ?u.umisteni,
      if (u.pocet != null) '${u.pocet} ks',
      if (u.vraceno != null)
        'vráceno ${AppDateFormat.date(u.vraceno!)}'
      else if (u.vratitDo != null)
        'vrátit ${AppDateFormat.date(u.vratitDo!)}',
    ];
    final pravidla = Dezen(zimni: u.zimni ?? false);

    return Padding(
      key: Key('ulozenka-${u.cislo}'),
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
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
          if (udaje.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              udaje.join(' · '),
              style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
            ),
          ],
          for (final k in u.kola)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      k.pozice,
                      style: AppTextStyles.metaSmall.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (k.pneu.isNotEmpty)
                          Text(
                            k.pneu,
                            style: AppTextStyles.metaSmall.copyWith(
                              color: palette.text,
                            ),
                          ),
                        if (k.udaje.isNotEmpty || k.poskozeni != null)
                          Text(
                            [
                              if (k.udaje.isNotEmpty) k.udaje,
                              ?k.poskozeni,
                            ].join(' · '),
                            style: AppTextStyles.metaSmall.copyWith(
                              color: palette.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (k.dezen != null)
                    Text(
                      '${formatMm(k.dezen!)} mm',
                      style: AppTextStyles.metaSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: barvaDezenu(
                          pravidla.stavKola(k.dezen!),
                          palette,
                        ),
                      ),
                    ),
                ],
              ),
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
