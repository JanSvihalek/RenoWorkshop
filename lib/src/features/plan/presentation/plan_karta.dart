import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/date_formats.dart';
import '../../akce/presentation/kampane_panel.dart' show barvaKampani;
import '../../orders/domain/entities/plan_klempirny.dart';
import '../../orders/domain/entities/service_order.dart';
import '../../orders/presentation/controllers/orders_providers.dart';
import '../../orders/presentation/widgets/detail_cards.dart';

/// Portál plánu klempírny (`/plan/` vedle API), nebo `null`, když appka
/// běží na ukázkových datech - tam není kam odkázat.
final adresaPlanovaceProvider = Provider<Uri?>(
  (ref) => ref.watch(pouzivaApiProvider)
      ? Uri.parse(AppConfig.apiBaseUrl).resolve('../plan/')
      : null,
);

/// Otevře odkaz mimo appku, v prohlížeči. V testech se podvrhne.
final otevritOdkazProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Zakázka v portálu plánu - otevře se její detail, odkud jde zaplánovat
/// a šipkou zpět do plánu.
Uri adresaZakazkyVPlanovaci(Uri planovac, String zakazkaId) =>
    planovac.replace(fragment: '/zakazky/${Uri.encodeComponent(zakazkaId)}');

/// „12. 10. – 14. 10. 2026", přes rok s rokem u obou.
String obdobiPlanu(DateTime od, DateTime do_) {
  final zacatek = od.year == do_.year
      ? AppDateFormat.dayMonth(od)
      : AppDateFormat.date(od);
  return '$zacatek – ${AppDateFormat.date(do_)}';
}

/// „1 den", „3 dny", „5 dní".
String pocetDni(int n) =>
    '$n ${n == 1
        ? 'den'
        : n >= 2 && n <= 4
        ? 'dny'
        : 'dní'}';

/// Karta Klempírna / lakovna v detailu zakázky. Plán jen ke čtení -
/// plánuje se v portálu plánu (`/plan/`), kam vede tlačítko „Otevřít
/// plánovač" (v prohlížeči, rovnou na téhle zakázce). U klempířských
/// zakázek vždy, u ostatních jen když plán už mají.
class PlanKarta extends ConsumerWidget {
  const PlanKarta({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plan = order.planKlempirny;
    final planovac = ref.watch(adresaPlanovaceProvider);

    Future<void> otevri(Uri planovac) async {
      final otevreno = await ref.read(otevritOdkazProvider)(
        adresaZakazkyVPlanovaci(planovac, order.id),
      );
      if (!otevreno && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plánovač se nepodařilo otevřít.')),
        );
      }
    }

    return DetailCard(
      key: const Key('plan-karta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('KLEMPÍRNA / LAKOVNA'),
          const SizedBox(height: Insets.sm),
          if (plan == null)
            Text(
              'Zatím nezaplánováno.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            )
          else
            _Plan(plan: plan, kodLaku: kodLakuZakazky(plan, order.barvaVozu)),
          if (planovac != null) ...[
            const SizedBox(height: Insets.md),
            OutlinedButton.icon(
              key: const Key('otevrit-planovac'),
              onPressed: () => otevri(planovac),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                plan == null ? 'Zaplánovat v plánovači' : 'Otevřít plánovač',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.plan, required this.kodLaku});

  final PlanKlempirny plan;
  final String? kodLaku;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${obdobiPlanu(plan.od, plan.do_)} · ${pocetDni(plan.dni)}',
              style: AppTextStyles.cardBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            StavPlanuZnacka(hotovo: plan.hotovo),
            if (kodLaku != null) KodLaku(kod: kodLaku!),
          ],
        ),
        if (plan.poznamka.trim().isNotEmpty) ...[
          const SizedBox(height: Insets.sm),
          Text(
            plan.poznamka,
            style: AppTextStyles.noteText.copyWith(color: palette.text),
          ),
        ],
        if (plan.zaplanoval != null) ...[
          const SizedBox(height: Insets.xs),
          Text(
            'Zaplánoval ${plan.zaplanoval}',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}

/// Naplánováno / Hotovo.
class StavPlanuZnacka extends StatelessWidget {
  const StavPlanuZnacka({super.key, required this.hotovo});

  final bool hotovo;

  @override
  Widget build(BuildContext context) {
    final barva = hotovo ? AppColors.readyGreen : barvaKampani(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: barva.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: barva.withValues(alpha: 0.5)),
      ),
      child: Text(
        hotovo ? 'HOTOVO' : 'NAPLÁNOVÁNO',
        style: AppTextStyles.overline.copyWith(
          fontSize: 10,
          color: barva,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// „KÓD 416" - kód laku jako štítek.
class KodLaku extends StatelessWidget {
  const KodLaku({super.key, required this.kod, this.naPruhu = false});

  final String kod;

  /// Na barevném pruhu v plánu - bílý podklad.
  final bool naPruhu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: naPruhu ? Colors.white : palette.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'KÓD ',
              style: AppTextStyles.overline.copyWith(
                fontSize: 9.5,
                color: naPruhu ? const Color(0xFF4A5568) : palette.muted,
              ),
            ),
            TextSpan(
              text: kod,
              style: AppTextStyles.metaSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: naPruhu ? const Color(0xFF1A2233) : palette.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
