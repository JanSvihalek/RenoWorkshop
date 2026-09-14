import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/service_order.dart';
import 'order_status_visuals.dart';
import 'plate_chip.dart';

/// Karta zakázky v seznamu. Jeden tap = detail.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.jeVybrana = false,
  });

  final ServiceOrder order;
  final VoidCallback onTap;

  /// V rozděleném zobrazení na tabletu: tahle zakázka je otevřená vedle.
  final bool jeVybrana;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bezMechanika = order.mechanicName == null;

    return _PressableCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: Insets.lg,
        ),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: jeVybrana ? AppColors.accent : palette.hairline,
            width: jeVybrana ? 2 : 1,
          ),
          boxShadow: palette.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.id,
                    style: AppTextStyles.orderNumber.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 9,
              runSpacing: 6,
              children: [
                PlateChip(licensePlate: order.licensePlate),
                Text(
                  order.model,
                  style: AppTextStyles.cardModel.copyWith(color: palette.text),
                ),
              ],
            ),
            // Typ zakázky má vlastní řádek. Ve Wrapu vedle modelu skákal
            // podle délky názvu - u krátkého se vešel vedle, u dlouhého
            // spadl pod něj - a karty pak nevypadaly stejně.
            if (order.typZakazky != null) ...[
              const SizedBox(height: 6),
              _TypChip(nazev: order.typZakazky!.nazev),
            ],
            const SizedBox(height: 7),
            Text(
              order.customerName,
              style: AppTextStyles.cardBody.copyWith(color: palette.muted2),
            ),
            // Co se opravuje - na klempírně podle toho člověk zakázku pozná
            // dřív než podle SPZ. Na kartě jen dva řádky, celé je v detailu.
            // Pojistná událost - na klempírně rozhoduje o tom, kdo platí
            // a na čí schválení se čeká.
            if (order.pojisteniPopisek case final pojisteni?) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: palette.muted),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      pojisteni,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (order.predmetOpravy case final predmet?) ...[
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.build_outlined,
                      size: 13,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      predmet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardBody.copyWith(
                        color: palette.text,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 9),
            // Dva nezávislé pohledy na tutéž zakázku, každý popsaný, ať se
            // nepletou: co o ní ví ERP a co dílna.
            _StavRadek(
              popisek: 'HELIOS',
              stav: order.heliosStatus,
              barva: AppColors.heliosGreen,
            ),
            const SizedBox(height: 4),
            _StavRadek(
              popisek: 'DÍLNA',
              stav: order.stav?.nazev,
              barva: order.stav?.color,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                // Levá část se zužuje, termín vpravo má vždycky přednost -
                // je to jediný údaj, který se na dílně čte na dálku.
                Expanded(
                  child: Row(
                    children: [
                      // Bez zodpovědné osoby nemá smysl zabírat místo
                      // avatarem a slovem "Nepřiřazeno".
                      if (!bezMechanika) ...[
                        _MechanicAvatar(initials: order.mechanicInitials),
                        const SizedBox(width: Insets.sm),
                        Flexible(
                          child: Text(
                            order.mechanicLabel,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.meta.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: palette.muted.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                      ],
                      // Útvar je vidět vždycky - filtruje se podle něj,
                      // takže musí být poznat, do kterého zakázka patří.
                      Flexible(
                        child: Text(
                          order.departmentLabel,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.meta.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                // Datum přijetí, ne termín dokončení: podle něj se seznam
                // řadí a u oprav po bouračce bývá termín nevyplněný.
                // Popisek je u něj proto, aby se nepletlo s termínem.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PŘIJATO',
                      style: AppTextStyles.overline.copyWith(
                        fontSize: 8.5,
                        color: palette.muted,
                      ),
                    ),
                    Text(
                      order.receivedAt == null
                          ? '—'
                          : AppDateFormat.dayMonthSmart(order.receivedAt!),
                      style: AppTextStyles.orderNumber.copyWith(
                        fontSize: 12.5,
                        color: palette.muted2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MechanicAvatar extends StatelessWidget {
  const _MechanicAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.avatar, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: palette.muted2,
        ),
      ),
    );
  }
}

/// Tap feedback z návrhu: krátké scale(.994) místo Material ripplu -
/// stejné chování na iOS i Androidu.
class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.994 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Typ zakázky - běžná, interní, klempířská. Nenápadný, protože u většiny
/// zakázek je běžný a pozornost patří stavu a termínu.
class _TypChip extends StatelessWidget {
  const _TypChip({required this.nazev});

  final String nazev;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      // Názvy řad z Heliosu bývají dlouhé („Klempířsko-lakýrnické práce").
      // Na kartě se čte hlavně SPZ, model a termín, takže typ ustoupí do
      // zkráceného tvaru; celý je vidět v detailu zakázky.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.42,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.badge),
        border: Border.all(color: palette.hairline2),
      ),
      child: Text(
        nazev,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
      ),
    );
  }
}

/// Jeden popsaný stav na kartě: štítek vlevo, hodnota vpravo.
///
/// Popisek je u každého schválně - bez něj by dva stavy pod sebou vypadaly
/// jako jeden údaj a nikdo by nepoznal, který je z Heliosu.
class _StavRadek extends StatelessWidget {
  const _StavRadek({
    required this.popisek,
    required this.stav,
    required this.barva,
  });

  final String popisek;
  final String? stav;
  final Color? barva;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            popisek,
            style: AppTextStyles.overline.copyWith(
              fontSize: 8.5,
              color: palette.muted,
            ),
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: barva ?? AppColors.pickedUpGrey,
              borderRadius: BorderRadius.circular(Radii.badge),
            ),
            child: Text(
              stav ?? 'Neuvedeno',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.badge.copyWith(
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
