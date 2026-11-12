import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../orders/domain/entities/dilensky_stav.dart';
import '../../akce/presentation/akce_providers.dart';
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/entities/service_order.dart';
import '../../orders/presentation/controllers/order_actions_controller.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../../orders/presentation/widgets/pridat_stav_sheet.dart';
import '../domain/prehled_planu.dart';
import 'okno_planu.dart';
import 'plan_karta.dart';
import 'plan_screen.dart' show cestaPlanovace;

/// Průběh opravy: plán (kdy se co má dělat) a dílenské stavy (co se opravdu
/// děje) v jedné ose. Zaplánování stav nezapíše, to dělá až Zahájit; Dokončit
/// krok uzavře a další čeká, až ho někdo zahájí. Ostatní zakázky se plánovat
/// nedají a mají jen postup stavů.
class OsaPrubehu extends ConsumerWidget {
  const OsaPrubehu({
    super.key,
    required this.order,
    this.onUpravit,
    this.onZrusit,
  });

  final ServiceOrder order;

  /// Úprava a zrušení zapsaného stavu (nabídka ⋯). `null` je schová -
  /// bez práva upravovat zakázku.
  final void Function(DilenskyStav stav)? onUpravit;
  final void Function(DilenskyStav stav)? onZrusit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plan = order.planKlempirny;
    final historie = order.historieStavu;
    final sPlanem = order.lzePlanovatKlempirnu || plan != null;
    // Plán jen s plánovačem „Plánovat" u pobočky zakázky; ten smí i zapsat stav.
    final smiPlan = ref.watch(smiPlanovatProvider(order.branch?.code));
    final smiStav =
        smiPlan || ref.watch(smiZapisovatProvider(order.poradac?.kod));
    final zaneprazdneno = ref.watch(orderActionsProvider).isLoading;
    final dnes = ref.watch(dnesProvider);
    final polozky = osaPrubehu(
      plan,
      historie,
      order.zruseneStavy,
      order.zruseneUkonyPlanu,
    );

    if (!sPlanem && historie.isEmpty && order.zruseneStavy.isEmpty) {
      return Text(
        'Zakázka zatím nemá žádný dílenský stav. Přidejte první tlačítkem výše.',
        style: AppTextStyles.cardBody.copyWith(color: palette.muted),
      );
    }

    final bezPlanu = sPlanem && plan == null;
    final pocet = polozky.length + (bezPlanu ? 1 : 0);

    return Column(
      key: const Key('osa-prubehu'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bezPlanu)
          _Radek(
            prvni: true,
            posledni: pocet == 1,
            tecka: const _Tecka.bezPlanu(),
            child: _RadekBezPlanu(
              key: const Key('osa-bez-planu'),
              nadpis: historie.isEmpty
                  ? 'Zatím bez plánu a stavů'
                  : 'Zakázka nemá plán',
              text: historie.isEmpty
                  ? 'Zaplánujte opravu, nebo přidejte první stav, až se na '
                        'voze začne pracovat.'
                  : 'Kroky z plánovače se zobrazí tady. Stavy lze přidávat '
                        'i bez plánu.',
            ),
          ),
        for (final (i, p) in polozky.indexed)
          _Polozka(
            key: p.zaznam?.id == null ? null : Key('osa-stav-${p.zaznam!.id}'),
            polozka: p,
            dnes: dnes,
            prvni: i == 0 && !bezPlanu,
            posledni: i == polozky.length - 1,
            onUpravit: p.ukon != null && smiPlan
                ? () => naplanovatKlempirnu(
                    context,
                    ref,
                    zakazkaId: order.id,
                    spz: order.licensePlate,
                    plan: plan,
                    ukon: p.ukon,
                    barva: order.barvaVozu,
                    zakazka: order,
                  )
                : null,
            onZahajit: p.ukon != null && smiStav
                ? () =>
                      pridatStavZakazce(context, ref, order, ukon: p.ukon!.typ)
                : null,
            onDokoncit: p.zaznam?.id != null && smiStav && !zaneprazdneno
                ? () => ref
                      .read(orderActionsProvider.notifier)
                      .dokonciStav(order.id, p.zaznam!.id!)
                : null,
            // Zrušený stav už jen ukazuje, co se stalo.
            onUpravitStav:
                p.zaznam?.id != null &&
                    p.stav != StavPolozky.zruseno &&
                    onUpravit != null
                ? () => onUpravit!(p.zaznam!)
                : null,
            onZrusit:
                p.zaznam?.id != null &&
                    p.stav != StavPolozky.zruseno &&
                    onZrusit != null
                ? () => onZrusit!(p.zaznam!)
                : null,
          ),
        if (sPlanem && ref.watch(vidiPlanovacProvider))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('otevrit-planovac'),
              onPressed: () => context.push(cestaPlanovace),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Otevřít plánovač'),
            ),
          ),
      ],
    );
  }
}

/// Doplněk nadpisu karty: období plánu s kódem laku, nebo „jen stavy".
class DoplnekPrubehu extends StatelessWidget {
  const DoplnekPrubehu({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = order.planKlempirny;
    final styl = AppTextStyles.monoLabel.copyWith(
      fontSize: 12,
      letterSpacing: 0,
      fontWeight: FontWeight.w600,
      color: palette.text,
    );
    if (plan == null) {
      return order.lzePlanovatKlempirnu && order.historieStavu.isNotEmpty
          ? Text('jen stavy', style: styl)
          : const SizedBox.shrink();
    }
    final kod = kodLakuZakazky(plan, order.barvaVozu);
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${kratkeObdobiPlanu(plan.od, plan.do_)} ${plan.do_.year}',
          style: styl,
        ),
        if (kod != null) KodLaku(kod: kod),
      ],
    );
  }
}

/// Řádek osy: čára s puntíkem a obsah. Pozadí jde přes obojí.
class _Radek extends StatelessWidget {
  const _Radek({
    required this.prvni,
    required this.posledni,
    required this.tecka,
    required this.child,
    this.pozadi,
    this.okraj,
  });

  final bool prvni;
  final bool posledni;
  final Widget tecka;
  final Widget child;
  final Color? pozadi;
  final Color? okraj;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget cara(bool skryta) => Expanded(
      child: Container(
        width: 2,
        color: skryta ? Colors.transparent : palette.hairline2,
      ),
    );
    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: pozadi,
          borderRadius: BorderRadius.circular(Radii.input),
          border: okraj == null ? null : Border.all(color: okraj!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(children: [cara(prvni), tecka, cara(posledni)]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.xs,
                  Insets.sm,
                  Insets.sm,
                  Insets.sm,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadekBezPlanu extends StatelessWidget {
  const _RadekBezPlanu({super.key, required this.nadpis, required this.text});

  final String nadpis;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nadpis,
          style: AppTextStyles.cardBody.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: palette.muted2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class _Polozka extends StatelessWidget {
  const _Polozka({
    super.key,
    required this.polozka,
    required this.dnes,
    required this.prvni,
    required this.posledni,
    this.onUpravit,
    this.onZahajit,
    this.onDokoncit,
    this.onUpravitStav,
    this.onZrusit,
  });

  final PolozkaOsy polozka;
  final DateTime dnes;
  final bool prvni;
  final bool posledni;

  /// Bez něj (jen čtení) úkon nejde otevřít.
  final VoidCallback? onUpravit;
  final VoidCallback? onZahajit;
  final VoidCallback? onDokoncit;
  final VoidCallback? onUpravitStav;
  final VoidCallback? onZrusit;

  /// „4. 11. 15:17", rok jen když není letošní.
  String _kdy(DateTime d) =>
      '${AppDateFormat.dayMonthSmart(d, now: dnes)} ${AppDateFormat.time(d)}';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = polozka;
    final mimo = p.mimoPlan && p.stav == StavPolozky.hotovo;
    final probiha = p.stav == StavPolozky.probiha;
    final zruseno = p.stav == StavPolozky.zruseno;
    final vPozadi =
        p.stav == StavPolozky.hotovo || p.stav == StavPolozky.ceka || zruseno;
    final cervena = context.isDarkMode
        ? const Color(0xFFFF7A7A)
        : AppColors.danger;

    final pod = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    final kdyKdo = [if (p.kdy != null) _kdy(p.kdy!), ?p.kdo].join(' · ');

    final nazev = Text(
      p.nazev,
      style: AppTextStyles.cardBody.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: zruseno
            ? palette.muted
            : vPozadi
            ? palette.muted2
            : palette.text,
        decoration: zruseno ? TextDecoration.lineThrough : null,
      ),
    );
    final upraveno = zruseno ? null : p.zaznam?.upraveno;

    final obsah = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Insets.sm,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (onUpravit != null && p.ukon != null)
              InkWell(
                key: Key('plan-ukon-${p.ukon!.id}'),
                onTap: onUpravit,
                child: nazev,
              )
            else
              nazev,
            if (p.mimoPlan) const _StitekMimoPlan(),
            if (zruseno)
              Container(
                key: const Key('osa-zruseno'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: cervena),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ZRUŠENO',
                  style: AppTextStyles.monoLabel.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: cervena,
                  ),
                ),
              ),
            if (upraveno != null)
              Tooltip(
                message: [
                  'Upraveno ${_kdy(upraveno)}',
                  ?p.zaznam?.upravil,
                ].join(' · '),
                child: Text(
                  'upraveno',
                  key: const Key('osa-upraveno'),
                  style: pod.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            if (p.do_ != null)
              Text(
                kratkeObdobiPlanu(p.od, p.do_!),
                style: AppTextStyles.monoLabel.copyWith(
                  fontSize: 12,
                  letterSpacing: 0,
                  color: palette.muted2,
                ),
              ),
            if (mimo && p.zaznam?.autor != null)
              Text(p.zaznam!.autor!, style: pod),
          ],
        ),
        if (probiha)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              key: const Key('osa-probiha'),
              'Probíhá${p.kdy != null ? ' od' : ''} $kdyKdo'.trimRight(),
              style: pod.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (p.stav == StavPolozky.hotovo && !mimo)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Dokončeno $kdyKdo'.trimRight(), style: pod),
          ),
        if (p.stav == StavPolozky.dalsi)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Další na řadě', style: pod),
          ),
        if (zruseno)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              p.zaznam == null
                  ? 'Úkon plánu zrušil $kdyKdo'.trimRight()
                  : [
                      'Zadal ${[if (p.zaznam!.zadano != null) _kdy(p.zaznam!.zadano!), ?p.zaznam!.autor].join(' · ')}',
                      'zrušil $kdyKdo'.trimRight(),
                    ].join(' · '),
              style: pod,
            ),
          ),
        if (p.poznamka != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(p.poznamka!, style: pod),
          ),
      ],
    );

    final radek = _Radek(
      prvni: prvni,
      posledni: posledni,
      tecka: _Tecka(p.stav, mimo: mimo),
      pozadi: probiha
          ? AppColors.accent.withValues(alpha: 0.1)
          : mimo
          ? palette.background
          : null,
      okraj: mimo ? palette.hairline : null,
      child: Row(
        children: [
          Expanded(child: obsah),
          // Úprava a zrušení jen u záznamů, které prošly serverem -
          // schované v nabídce, ať se nezmáčknou omylem.
          if (onUpravitStav != null || onZrusit != null)
            PopupMenuButton<VoidCallback>(
              key: Key('osa-menu-${p.zaznam?.id}'),
              tooltip: 'Další akce',
              icon: Icon(Icons.more_horiz, size: 20, color: palette.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 160),
              onSelected: (akce) => akce(),
              itemBuilder: (_) => [
                if (onUpravitStav != null)
                  PopupMenuItem(
                    key: const Key('osa-upravit'),
                    value: onUpravitStav,
                    child: const Text('Upravit stav'),
                  ),
                if (onZrusit != null)
                  PopupMenuItem(
                    key: const Key('osa-zrusit'),
                    value: onZrusit,
                    child: const Text('Zrušit stav'),
                  ),
              ],
            ),
          if (p.stav == StavPolozky.dalsi &&
              onZahajit != null &&
              p.ukon != null)
            Padding(
              padding: const EdgeInsets.only(left: Insets.sm),
              child: OutlinedButton(
                key: Key('plan-zahajit-${p.ukon!.id}'),
                onPressed: onZahajit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.base),
                ),
                child: const Text('Zahájit'),
              ),
            ),
          if (probiha && onDokoncit != null)
            Padding(
              padding: const EdgeInsets.only(left: Insets.sm),
              child: FilledButton(
                key: const Key('dokoncit-stav'),
                onPressed: onDokoncit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.base),
                  // Tmavomodrá by na tmavém pozadí zanikla.
                  backgroundColor: context.isDarkMode
                      ? AppColors.accent
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: AppTextStyles.chip,
                ),
                child: const Text('Dokončit'),
              ),
            ),
        ],
      ),
    );
    final kdo = p.ukon?.zaplanoval;
    return kdo == null
        ? radek
        : Tooltip(message: 'Zaplánoval $kdo', child: radek);
  }
}

class _StitekMimoPlan extends StatelessWidget {
  const _StitekMimoPlan();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: palette.muted2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'MIMO PLÁN',
        style: AppTextStyles.monoLabel.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: palette.card,
        ),
      ),
    );
  }
}

/// Puntík na ose: prázdný čeká, zelený hotovo, modrý probíhá, kosočtverec
/// mimo plán, čárkovaný bez plánu.
class _Tecka extends StatelessWidget {
  const _Tecka(this.stav, {this.mimo = false}) : bezPlanu = false;
  const _Tecka.bezPlanu() : stav = null, mimo = false, bezPlanu = true;

  final StavPolozky? stav;
  final bool mimo;
  final bool bezPlanu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (bezPlanu) {
      return CustomPaint(
        size: const Size(11, 11),
        painter: _CarkovanyKruh(palette.muted),
      );
    }
    if (mimo) {
      return Transform.rotate(
        angle: pi / 4,
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: palette.muted2,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }
    return switch (stav) {
      StavPolozky.zruseno => CustomPaint(
        size: const Size(10, 10),
        painter: _CarkovanyKruh(palette.muted),
      ),
      StavPolozky.probiha => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.25),
              spreadRadius: 3,
            ),
          ],
        ),
      ),
      StavPolozky.hotovo => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.isDarkMode
              ? const Color(0xFF81C784)
              : AppColors.heliosGreen,
        ),
      ),
      _ => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.card,
          border: Border.all(color: palette.muted, width: 1.5),
        ),
      ),
    };
  }
}

class _CarkovanyKruh extends CustomPainter {
  const _CarkovanyKruh(this.barva);

  final Color barva;

  @override
  void paint(Canvas canvas, Size size) {
    final stred = size.center(Offset.zero);
    final polomer = size.width / 2 - 0.75;
    final stetec = Paint()
      ..color = barva
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dilku = 8;
    for (var i = 0; i < dilku; i++) {
      final od = i * 2 * pi / dilku;
      canvas.drawLine(
        stred + Offset(cos(od), sin(od)) * polomer,
        stred + Offset(cos(od + 0.4), sin(od + 0.4)) * polomer,
        stetec,
      );
    }
  }

  @override
  bool shouldRepaint(_CarkovanyKruh stary) => stary.barva != barva;
}
