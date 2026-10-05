import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/zpracovatel.dart';
import '../controllers/orders_providers.dart';

/// Co uživatel v okně zpracovatele zvolil. Provede to až detail - chyby
/// ukazuje jednotně přes controller.
sealed class VolbaZpracovatele {
  const VolbaZpracovatele();
}

/// Zpracovatelem se stane přihlášený.
class PrevzitZakazku extends VolbaZpracovatele {
  const PrevzitZakazku();
}

/// Zpracovatelem se stane vybraný kolega.
class PriraditZamestnance extends VolbaZpracovatele {
  const PriraditZamestnance(this.id);

  final int id;
}

/// Zakázku nikdo nezpracovává.
class UvolnitZakazku extends VolbaZpracovatele {
  const UvolnitZakazku();
}

/// Okno pro výběr zpracovatele: nahoře „Převzít" pro sebe, pod ním kolegové
/// z útvaru zakázky (na požádání všichni) a dole uvolnění zakázky.
///
/// [mujEmail] je e-mail přihlášeného - když zakázku už zpracovává on,
/// „Převzít" nemá smysl.
Future<VolbaZpracovatele?> vyberZpracovatele(
  BuildContext context, {
  required String orderId,
  Zpracovatel? aktualni,
  String? mujEmail,
}) {
  return showModalBottomSheet<VolbaZpracovatele>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ZpracovatelSheet(
      orderId: orderId,
      aktualni: aktualni,
      mujEmail: mujEmail,
    ),
  );
}

class _ZpracovatelSheet extends ConsumerStatefulWidget {
  const _ZpracovatelSheet({
    required this.orderId,
    this.aktualni,
    this.mujEmail,
  });

  final String orderId;
  final Zpracovatel? aktualni;
  final String? mujEmail;

  @override
  ConsumerState<_ZpracovatelSheet> createState() => _ZpracovatelSheetState();
}

class _ZpracovatelSheetState extends ConsumerState<_ZpracovatelSheet> {
  final _hledani = TextEditingController();

  /// Všichni zaměstnanci místo lidí z útvaru zakázky.
  bool _vsichni = false;

  @override
  void dispose() {
    _hledani.dispose();
    super.dispose();
  }

  bool _odpovida(ZamestnanecKVyberu clovek) {
    final dotaz = _hledani.text.trim().toLowerCase();
    if (dotaz.isEmpty) return true;
    return '${clovek.jmeno} ${clovek.kod ?? ''} ${clovek.utvar?.label ?? ''}'
        .toLowerCase()
        .contains(dotaz);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final aktualni = widget.aktualni;
    final jsemTo = aktualni?.jeEmail(widget.mujEmail) ?? false;
    final nabidka = ref.watch(
      nabidkaZpracovateluProvider((orderId: widget.orderId, vsichni: _vsichni)),
    );
    final vyska = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          // Seznam lidí bývá dlouhý - okno nesmí přerůst obrazovku.
          constraints: BoxConstraints(maxHeight: vyska * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xxl,
              Insets.xl,
              Insets.xxl,
              Insets.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Zpracovatel zakázky',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: palette.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Zavřít',
                      color: palette.muted,
                    ),
                  ],
                ),
                Text(
                  aktualni == null
                      ? 'Zakázku teď nikdo nezpracovává.'
                      : 'Teď: ${aktualni.jmeno}'
                            '${aktualni.od == null ? '' : ' · od ${AppDateFormat.dayMonthSmart(aktualni.od!)}'}',
                  style: AppTextStyles.meta.copyWith(color: palette.muted),
                ),
                if (!jsemTo) ...[
                  const SizedBox(height: Insets.lg),
                  SizedBox(
                    width: double.infinity,
                    height: Sizes.ctaHeight,
                    child: FilledButton.icon(
                      key: const Key('prevzit-zakazku'),
                      onPressed: () =>
                          Navigator.of(context).pop(const PrevzitZakazku()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.back_hand_outlined, size: 20),
                      label: Text(
                        'Převzít zakázku',
                        style: AppTextStyles.buttonLabel,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Insets.lg),
                Text(
                  'NEBO PŘIŘADIT KOLEGOVI',
                  style: AppTextStyles.overline.copyWith(color: palette.muted),
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  key: const Key('hledat-zpracovatele'),
                  controller: _hledani,
                  style: AppTextStyles.cardBody.copyWith(color: palette.text),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'Hledat podle jména',
                    hintStyle: AppTextStyles.cardBody.copyWith(
                      color: palette.muted,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.input),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Insets.sm),
                _PrepinacUtvaru(
                  nabidka: nabidka.valueOrNull,
                  vsichni: _vsichni,
                  onZmena: (vsichni) => setState(() => _vsichni = vsichni),
                ),
                const SizedBox(height: Insets.xs),
                Flexible(
                  child: nabidka.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: Insets.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (chyba, _) => _Hlaska(
                      'Seznam lidí se nepodařilo načíst. Převzít jde i tak.',
                    ),
                    data: (nabidka) {
                      final lide = nabidka.lide.where(_odpovida).toList();
                      if (lide.isEmpty) {
                        return _Hlaska(
                          nabidka.lide.isEmpty
                              ? (nabidka.jenUtvar
                                    ? 'V útvaru zakázky nikdo není. '
                                          'Zkuste všechny útvary.'
                                    : 'Seznam zaměstnanců je zatím prázdný.')
                              : 'Nikdo takový.',
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: lide.length,
                        itemBuilder: (context, index) {
                          final clovek = lide[index];
                          final vybrany = clovek.id == aktualni?.id;
                          return ListTile(
                            key: Key('zpracovatel-${clovek.id}'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              clovek.jmeno,
                              style: AppTextStyles.cardBody.copyWith(
                                color: palette.text,
                                fontWeight: vybrany
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            // Útvar jen v nabídce všech - v nabídce
                            // útvaru je u všech stejný.
                            subtitle: _vsichni && clovek.utvar != null
                                ? Text(
                                    clovek.utvar!.label,
                                    style: AppTextStyles.meta.copyWith(
                                      color: palette.muted,
                                    ),
                                  )
                                : null,
                            trailing: vybrany
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.accent,
                                  )
                                : null,
                            onTap: vybrany
                                ? null
                                : () => Navigator.of(
                                    context,
                                  ).pop(PriraditZamestnance(clovek.id)),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (aktualni != null) ...[
                  const SizedBox(height: Insets.sm),
                  Center(
                    child: TextButton(
                      key: const Key('uvolnit-zakazku'),
                      onPressed: () =>
                          Navigator.of(context).pop(const UvolnitZakazku()),
                      child: const Text('Uvolnit - nikdo nezpracovává'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Útvar zakázky, nebo všichni. Bez útvaru zakázky není co přepínat.
class _PrepinacUtvaru extends StatelessWidget {
  const _PrepinacUtvaru({
    required this.nabidka,
    required this.vsichni,
    required this.onZmena,
  });

  final NabidkaZpracovatelu? nabidka;
  final bool vsichni;
  final ValueChanged<bool> onZmena;

  @override
  Widget build(BuildContext context) {
    final utvar = nabidka?.utvarZakazky;
    if (utvar == null) return const SizedBox.shrink();
    return Wrap(
      spacing: Insets.sm,
      children: [
        ChoiceChip(
          key: const Key('zpracovatele-utvar'),
          label: Text(utvar.label),
          selected: !vsichni,
          onSelected: (_) => onZmena(false),
        ),
        ChoiceChip(
          key: const Key('zpracovatele-vsichni'),
          label: const Text('Všechny útvary'),
          selected: vsichni,
          onSelected: (_) => onZmena(true),
        ),
      ],
    );
  }
}

class _Hlaska extends StatelessWidget {
  const _Hlaska(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      child: Text(
        text,
        style: AppTextStyles.cardBody.copyWith(color: context.palette.muted),
      ),
    );
  }
}
