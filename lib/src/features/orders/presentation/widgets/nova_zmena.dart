import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/barvy_zmen.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/nova_zmena.dart';
import '../../domain/entities/service_order.dart';

/// Změněná zakázka - oranžový proužek, tečka a kroužek kolem stavu dílna.
/// Barvy jen z [BarvyZmen]. Jako na webu (zakazky/ZnackyZmen.tsx).

/// Obsah tooltipu změny: nadpis, co se stalo, kdy a kdo.
typedef PopisZmeny = ({String nadpis, String co, String kdy});

/// „ZMĚNA · STAV DÍLNA", „Bez stavu → Kontrola při průjezdu",
/// „dnes 10:42 · Hanák Petr". Předchozí stav se vezme z historie zakázky
/// (záznam před tím, který změnu udělal).
PopisZmeny popisZmeny(ServiceOrder order, NovaZmena zmena, DateTime ted) {
  final kdy = zmena.kdy;
  final hodiny = '${kdy.hour}:${kdy.minute.toString().padLeft(2, '0')}';
  bool stejnyDen(DateTime d) =>
      d.year == kdy.year && d.month == kdy.month && d.day == kdy.day;
  final den = stejnyDen(ted)
      ? 'dnes $hodiny'
      : stejnyDen(ted.subtract(const Duration(days: 1)))
      ? 'včera $hodiny'
      : '${kdy.day}. ${kdy.month}.${kdy.year == ted.year ? '' : ' ${kdy.year}'} '
            '$hodiny';
  final dalsi = zmena.pocet > 1 ? ' · +${zmena.pocet - 1} další' : '';
  return (
    nadpis: zmena.druh == DruhZmeny.poznamka
        ? 'Změna · Poznámka'
        : 'Změna · Stav dílna',
    co: _coSeZmenilo(order, zmena),
    kdy: '${[den, ?zmena.kdo].join(' · ')}$dalsi',
  );
}

String _coSeZmenilo(ServiceOrder order, NovaZmena zmena) {
  if (zmena.druh == DruhZmeny.poznamka) return '„${zmena.popisek}"';
  if (zmena.druh != DruhZmeny.stav) return zmena.text;
  final historie = order.historieStavu;
  final i = historie.indexWhere(
    (s) => s.zadano == zmena.kdy && s.nazev == zmena.popisek,
  );
  // Záznam v historii není (zrušený, nebo ho starší služba neposílá).
  if (i == -1) return zmena.text;
  final predtim = i + 1 < historie.length ? historie[i + 1].nazev : 'Bez stavu';
  return '$predtim → ${zmena.popisek}';
}

/// „1 zakázka se změnila", „3 zakázky se změnily", „5 zakázek se
/// změnilo" - s „od vašeho posledního zobrazení".
String textListyZmen(int pocet) {
  final veta = pocet == 1
      ? 'zakázka se změnila'
      : pocet >= 2 && pocet <= 4
      ? 'zakázky se změnily'
      : 'zakázek se změnilo';
  return '$pocet $veta od vašeho posledního zobrazení';
}

/// Tmavý tooltip změny. Na dotyku dlouhým stiskem, s myší najetím.
class TooltipZmeny extends StatelessWidget {
  const TooltipZmeny({super.key, required this.popis, required this.child});

  final PopisZmeny popis;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final barvy = context.barvyZmen;
    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${popis.nadpis.toUpperCase()}\n',
            style: AppTextStyles.overline.copyWith(
              fontSize: 10,
              color: barvy.tooltipTlumene,
            ),
          ),
          TextSpan(
            text: '${popis.co}\n',
            style: AppTextStyles.cardBody.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: barvy.tooltipText,
            ),
          ),
          TextSpan(
            text: popis.kdy,
            style: AppTextStyles.metaSmall.copyWith(
              color: barvy.tooltipTlumene,
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: barvy.tooltip,
        borderRadius: BorderRadius.circular(Radii.badge + 2),
      ),
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: child,
    );
  }
}

/// Tečka změněné zakázky (8 px). Pulzuje jen třikrát, pak stojí - při
/// vypnutých animacích v systému vůbec. Controller má jen změněná
/// zakázka a po třetím cyklu se zastaví; novou změnu spustí klíč podle
/// jejího času.
class TeckaZmeny extends StatefulWidget {
  const TeckaZmeny({super.key, this.velikost = 8, this.pulzovat = true});

  final double velikost;
  final bool pulzovat;

  /// Délka jednoho cyklu pulzu a jejich počet.
  static const cyklus = Duration(milliseconds: 1400);
  static const pocetCyklu = 3;

  @override
  State<TeckaZmeny> createState() => _TeckaZmenyState();
}

class _TeckaZmenyState extends State<TeckaZmeny>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulz;
  int _cyklu = 0;
  bool _spusteno = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_spusteno || !widget.pulzovat) return;
    _spusteno = true;
    if (MediaQuery.of(context).disableAnimations) return;
    _pulz = AnimationController(vsync: this, duration: TeckaZmeny.cyklus)
      ..addStatusListener((stav) {
        if (stav != AnimationStatus.completed) return;
        if (++_cyklu < TeckaZmeny.pocetCyklu) {
          _pulz!.forward(from: 0);
        } else {
          // Hotovo - tečka stojí, žádný běžící ticker.
          _pulz!.value = 0;
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _pulz?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final akcent = context.barvyZmen.akcent;
    Widget tecka(double t) => Container(
      width: widget.velikost,
      height: widget.velikost,
      decoration: BoxDecoration(
        color: akcent,
        shape: BoxShape.circle,
        boxShadow: t == 0
            ? null
            : [
                BoxShadow(
                  color: akcent.withValues(alpha: 0.5 * (1 - t)),
                  spreadRadius: 8 * t,
                ),
              ],
      ),
    );
    final pulz = _pulz;
    if (pulz == null) return tecka(0);
    return AnimatedBuilder(
      animation: pulz,
      builder: (_, _) => tecka(pulz.value),
    );
  }
}

/// Tečka změněné zakázky i s tooltipem, co se změnilo. U nezměněné nic.
class TeckaZmenyZakazky extends StatelessWidget {
  const TeckaZmenyZakazky({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final zmena = order.novaZmena;
    if (zmena == null) return const SizedBox.shrink();
    return TooltipZmeny(
      popis: popisZmeny(order, zmena, DateTime.now()),
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxs),
        child: TeckaZmeny(key: ValueKey('tecka-${order.id}-${zmena.kdy}')),
      ),
    );
  }
}

/// Štítek Stav dílna se změnou: kroužek (2 px mezera + 2 px akcent)
/// a tečka v rohu, tooltip „starý → nový stav". Kreslí se přes okolí,
/// takže štítek nezmění velikost. Jen u změny stavu - poznámka stav nemění.
class StavSeZmenou extends StatelessWidget {
  const StavSeZmenou({super.key, required this.order, required this.child});

  final ServiceOrder order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final zmena = order.novaZmena;
    if (zmena == null || !zmena.jeZmenaStavu) return child;
    final barvy = context.barvyZmen;
    final mezera = context.palette.card;
    const radius = Radii.badge;

    return TooltipZmeny(
      popis: popisZmeny(order, zmena, DateTime.now()),
      child: Stack(
        key: const Key('stav-se-zmenou'),
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: barvy.akcent, width: 2),
                  borderRadius: BorderRadius.circular(radius + 4),
                ),
              ),
            ),
          ),
          Positioned(
            left: -2,
            top: -2,
            right: -2,
            bottom: -2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: mezera, width: 2),
                  borderRadius: BorderRadius.circular(radius + 2),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: barvy.akcent,
                shape: BoxShape.circle,
                border: Border.all(color: mezera, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lišta nad seznamem: kolik zakázek se změnilo, „Zobrazit jen změněné"
/// (podruhé vypne) a „Označit vše jako přečtené". Zalamuje se.
class ListaZmen extends StatelessWidget {
  const ListaZmen({
    super.key,
    required this.pocet,
    required this.jenZmenene,
    required this.onJenZmenene,
    required this.onOznacitVse,
  });

  final int pocet;
  final bool jenZmenene;
  final ValueChanged<bool> onJenZmenene;

  /// `null` = právě se ukládá.
  final VoidCallback? onOznacitVse;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = context.barvyZmen;

    return Container(
      key: const Key('lista-zmen'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: barvy.pozadiRadku,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: barvy.okraj),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Insets.md,
        runSpacing: Insets.xs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TeckaZmeny(pulzovat: false),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: Text(
                  textListyZmen(pocet),
                  style: AppTextStyles.metaSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
          OutlinedButton(
            key: const Key('lista-zmen-jen-zmenene'),
            onPressed: () => onJenZmenene(!jenZmenene),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: barvy.text,
              backgroundColor: jenZmenene
                  ? Color.alphaBlend(
                      barvy.akcent.withValues(alpha: 0.14),
                      palette.card,
                    )
                  : palette.card,
              side: BorderSide(
                color: jenZmenene ? barvy.akcent : barvy.okraj,
                width: 1.5,
              ),
              textStyle: AppTextStyles.metaSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Zobrazit jen změněné'),
          ),
          TextButton(
            key: const Key('lista-zmen-oznacit-vse'),
            onPressed: onOznacitVse,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: palette.muted,
              textStyle: AppTextStyles.metaSmall,
            ),
            child: const Text('Označit vše jako přečtené'),
          ),
        ],
      ),
    );
  }
}

/// Pruh nahoře v detailu: co bylo nového při otevření. Zůstane, i když
/// zvýraznění v seznamu hned zmizí; křížkem se schová.
class PruhOdPosledniNavstevy extends StatelessWidget {
  const PruhOdPosledniNavstevy({
    super.key,
    required this.zmena,
    required this.onSkryt,
  });

  final NovaZmena zmena;
  final VoidCallback onSkryt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barvy = context.barvyZmen;
    final dalsi = zmena.pocet > 1 ? ' a ${zmena.pocet - 1} další' : '';

    return Container(
      key: const Key('detail-nova-zmena'),
      padding: const EdgeInsets.fromLTRB(Insets.base, Insets.xs, 0, Insets.xs),
      decoration: BoxDecoration(
        color: barvy.pozadiRadku,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: barvy.okraj),
      ),
      child: Row(
        children: [
          const TeckaZmeny(pulzovat: false),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Od vaší poslední návštěvy: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '${zmena.text}$dalsi'),
                  TextSpan(
                    text: ' · ${zmena.kdoKdy(DateTime.now())}',
                    style: TextStyle(color: palette.muted),
                  ),
                ],
              ),
              style: AppTextStyles.cardBody.copyWith(
                fontSize: 13.5,
                color: palette.text,
              ),
            ),
          ),
          IconButton(
            key: const Key('detail-nova-zmena-skryt'),
            tooltip: 'Skrýt',
            visualDensity: VisualDensity.compact,
            onPressed: onSkryt,
            icon: Icon(Icons.close_rounded, size: 18, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
