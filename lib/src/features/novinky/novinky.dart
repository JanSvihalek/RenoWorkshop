/// Okno „Co je nového" - stejné jako na webu (web/src/novinky/Novinky.tsx).
/// Texty píše služba (`GET /news`), co už člověk viděl, si pamatuje jeho
/// účet (`newsSeen` v `/me/settings`): zavře-li novinky v telefonu, na
/// webu se mu znovu neukážou.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/date_formats.dart';
import '../orders/presentation/controllers/orders_providers.dart';
import '../settings/data/nastaveni_uctu_data_source.dart';

class Novinka {
  const Novinka({
    required this.id,
    required this.datum,
    required this.nadpis,
    required this.text,
  });

  final String id;
  final DateTime datum;
  final String nadpis;
  final String text;

  static Novinka? fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'date': final String datum,
      'title': final String nadpis,
      'text': final String text,
    } =>
      Novinka(
        id: id,
        datum: DateTime.tryParse(datum) ?? DateTime(2026),
        nadpis: nadpis,
        text: text,
      ),
    _ => null,
  };
}

/// Novinky ze služby - implementuje ji stejná služba jako zakázky.
abstract interface class NovinkyDataSource {
  /// Nejnovější první; služba už vynechá ty jen pro admina, když jím
  /// přihlášený není.
  Future<List<Novinka>> nactiNovinky();
}

/// Co ještě neviděl: novinky novější než [videl]. Kdo ještě nic neviděl
/// (nebo jeho novinka zmizela), dostane jen tu nejnovější.
List<Novinka> noveNovinky(List<Novinka> novinky, String? videl) {
  if (novinky.isEmpty) return const [];
  final kde = videl == null ? -1 : novinky.indexWhere((n) => n.id == videl);
  return kde == -1 ? novinky.take(1).toList() : novinky.take(kde).toList();
}

/// Všechny novinky - prázdné, když zdroj dat novinky nemá (ukázková data).
final novinkyProvider = FutureProvider<List<Novinka>>((ref) async {
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  return zdroj is NovinkyDataSource
      ? (zdroj as NovinkyDataSource).nactiNovinky()
      : const [];
});

/// Okno se seznamem novinek.
Future<void> ukazNovinky(BuildContext context, List<Novinka> novinky) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final palette = context.palette;
        return AlertDialog(
          key: const Key('okno-novinek'),
          title: const Text('Co je nového'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, n) in novinky.indexed) ...[
                    if (i > 0) const SizedBox(height: Insets.lg),
                    Container(
                      padding: const EdgeInsets.only(left: Insets.md),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.accent, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppDateFormat.date(n.datum),
                            style: AppTextStyles.metaSmall.copyWith(
                              color: palette.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.nadpis,
                            style: AppTextStyles.cardBody.copyWith(
                              color: palette.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.text,
                            style: AppTextStyles.metaSmall.copyWith(
                              color: palette.muted2,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              key: const Key('novinky-rozumim'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Rozumím'),
            ),
          ],
        );
      },
    );

/// Po přihlášení ukáže novinky, které člověk ještě neviděl, a po zavření
/// si na účtu poznamená tu nejnovější. Když služba neodpoví, neukáže nic
/// a zkusí to příště.
class HlidacNovinek extends ConsumerStatefulWidget {
  const HlidacNovinek({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HlidacNovinek> createState() => _HlidacNovinekState();
}

class _HlidacNovinekState extends ConsumerState<HlidacNovinek> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _zkontroluj());
  }

  Future<void> _zkontroluj() async {
    final zdroj = ref.read(serviceOrderDataSourceProvider);
    if (zdroj is! NastaveniUctuDataSource || zdroj is! NovinkyDataSource) {
      return;
    }
    final ucet = zdroj as NastaveniUctuDataSource;
    try {
      final novinky = await ref.read(novinkyProvider.future);
      final videl = (await ucet.nactiNastaveniUctu())['newsSeen'];
      final nove = noveNovinky(novinky, videl is String ? videl : null);
      if (nove.isEmpty || !mounted) return;
      await ukazNovinky(context, nove);
      await ucet.ulozNastaveniUctu({'newsSeen': novinky.first.id});
    } on Object {
      // Novinky nejsou důležitější než práce - když nejdou, nic se neděje.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
