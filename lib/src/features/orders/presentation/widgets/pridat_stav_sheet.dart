import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../controllers/orders_providers.dart';

/// Co uživatel vyplnil: stav z číselníku nebo vlastní text, a k tomu
/// nepovinná poznámka.
class VybranyStav {
  const VybranyStav({this.kod, this.nazev, this.poznamka, this.misto});

  final String? kod;
  final String? nazev;

  /// Na co se čeká, co se domluvilo.
  final String? poznamka;

  /// Kde vůz po tomhle kroku stojí. `null` = nechat, co tam je,
  /// prázdný text místo smaže.
  final String? misto;
}

/// Formulář pro přidání dílenského stavu.
///
/// Jedno okno: nahoře výběr stavu, pod ním poznámka, dole potvrzení.
/// Dřív se stav ukládal hned po klepnutí v seznamu a poznámka se musela
/// napsat dopředu — tedy dřív, než člověk věděl, k čemu ji píše.
/// [misto] je místo, kde vůz stojí teď - předvyplní se, ať ho technik
/// při každém kroku nepíše znovu.
Future<VybranyStav?> vyberStav(BuildContext context, {String? misto}) {
  return showModalBottomSheet<VybranyStav>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PridatStavSheet(misto: misto),
  );
}

/// Hodnota v seznamu, která znamená „stav mimo číselník".
const _jiny = '__jiny__';

class _PridatStavSheet extends ConsumerStatefulWidget {
  const _PridatStavSheet({this.misto});

  final String? misto;

  @override
  ConsumerState<_PridatStavSheet> createState() => _PridatStavSheetState();
}

class _PridatStavSheetState extends ConsumerState<_PridatStavSheet> {
  final _vlastni = TextEditingController();
  final _poznamka = TextEditingController();
  late final _misto = TextEditingController(text: widget.misto ?? '');

  /// Kód vybraného stavu, `_jiny` u vlastního, `null` dokud nic nevybral.
  String? _vybrany;

  @override
  void dispose() {
    _vlastni.dispose();
    _poznamka.dispose();
    _misto.dispose();
    super.dispose();
  }

  bool get _jeVlastni => _vybrany == _jiny;

  /// Přidat jde, teprve když je co uložit.
  bool get _lzePridat =>
      _vybrany != null && (!_jeVlastni || _vlastni.text.trim().isNotEmpty);

  void _potvrd() {
    if (!_lzePridat) return;
    final poznamka = _poznamka.text.trim();
    final misto = _misto.text.trim();

    Navigator.of(context).pop(
      VybranyStav(
        kod: _jeVlastni ? null : _vybrany,
        nazev: _jeVlastni ? _vlastni.text.trim() : null,
        poznamka: poznamka.isEmpty ? null : poznamka,
        // Beze změny se místo neposílá - ať se u něj nepřepisuje čas
        // zápisu, když vůz zůstal stát.
        misto: misto == (widget.misto ?? '') ? null : misto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final nabidka = ref.watch(nabidkaStavuProvider);

    return SafeArea(
      child: Padding(
        // Klávesnice nesmí překrýt pole, do kterého se zrovna píše.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Insets.xxl,
            Insets.xl,
            Insets.xxl,
            Insets.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Přidat stav',
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
              const SizedBox(height: Insets.sm),

              const _Popisek('STAV'),
              const SizedBox(height: Insets.xs),
              nabidka.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: Insets.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // Výpadek nabídky nesmí zabránit zápisu stavu - zbývá
                // vlastní text, což je pořád lepší než nic.
                error: (_, _) => _NabidkaChybi(
                  text: 'Nabídku stavů se nepodařilo načíst.',
                  jeVlastni: _jeVlastni,
                  onVlastni: () => setState(() => _vybrany = _jiny),
                ),
                data: (stavy) => stavy.isEmpty
                    ? _NabidkaChybi(
                        text: 'Číselník stavů je zatím prázdný.',
                        jeVlastni: _jeVlastni,
                        onVlastni: () => setState(() => _vybrany = _jiny),
                      )
                    : _VyberStavu(
                        stavy: stavy,
                        vybrany: _vybrany,
                        onZmena: (kod) => setState(() => _vybrany = kod),
                      ),
              ),

              if (_jeVlastni) ...[
                const SizedBox(height: Insets.base),
                const _Popisek('VLASTNÍ STAV'),
                const SizedBox(height: Insets.xs),
                TextField(
                  controller: _vlastni,
                  autofocus: true,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.cardBody.copyWith(color: palette.text),
                  decoration: _vzhledPole(
                    context,
                    'Např. Čeká na díl z Německa',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: Insets.base),
              // Vůz se hýbe právě tehdy, když se mění, co se s ním děje -
              // proto se na místo ptáme u každého kroku.
              const _Popisek('KDE VŮZ STOJÍ'),
              const SizedBox(height: Insets.xs),
              TextField(
                key: const Key('stav-misto'),
                controller: _misto,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.cardBody.copyWith(color: palette.text),
                decoration: _vzhledPole(context, 'Např. stání 4, lakovna'),
              ),

              const SizedBox(height: Insets.base),
              const _Popisek('POZNÁMKA (NEPOVINNÁ)'),
              const SizedBox(height: Insets.xs),
              TextField(
                controller: _poznamka,
                maxLength: 500,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.cardBody.copyWith(color: palette.text),
                decoration: _vzhledPole(context, 'Např. čeká na díl'),
              ),

              const SizedBox(height: Insets.xl),
              SizedBox(
                width: double.infinity,
                height: Sizes.ctaHeight,
                child: FilledButton(
                  onPressed: _lzePridat ? _potvrd : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: palette.plate,
                  ),
                  child: Text('Přidat', style: AppTextStyles.buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _vzhledPole(BuildContext context, String napoveda) {
    final palette = context.palette;
    return InputDecoration(
      isDense: true,
      counterText: '',
      hintText: napoveda,
      hintStyle: AppTextStyles.cardBody.copyWith(color: palette.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
      ),
    );
  }
}

class _VyberStavu extends StatelessWidget {
  const _VyberStavu({
    required this.stavy,
    required this.vybrany,
    required this.onZmena,
  });

  final List<NabidkaStavu> stavy;
  final String? vybrany;
  final ValueChanged<String?> onZmena;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.base),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.input),
        border: Border.all(color: palette.hairline2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: vybrany,
          isExpanded: true,
          hint: Text(
            'Vyberte stav',
            style: AppTextStyles.cardBody.copyWith(color: palette.muted),
          ),
          borderRadius: BorderRadius.circular(Radii.input),
          dropdownColor: palette.card,
          style: AppTextStyles.cardBody.copyWith(color: palette.text),
          items: [
            for (final stav in stavy)
              DropdownMenuItem(value: stav.kod, child: Text(stav.nazev)),
            // Na dílně se objeví situace, kterou nikdo dopředu nevymyslel;
            // čekat kvůli ní na úpravu číselníku by znamenalo, že se stav
            // nezapíše vůbec.
            DropdownMenuItem(
              value: _jiny,
              child: Text(
                'Jiný…',
                style: AppTextStyles.cardBody.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          onChanged: onZmena,
        ),
      ),
    );
  }
}

class _NabidkaChybi extends StatelessWidget {
  const _NabidkaChybi({
    required this.text,
    required this.jeVlastni,
    required this.onVlastni,
  });

  final String text;
  final bool jeVlastni;
  final VoidCallback onVlastni;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: AppTextStyles.cardBody.copyWith(color: palette.muted),
        ),
        if (!jeVlastni) ...[
          const SizedBox(height: Insets.sm),
          OutlinedButton.icon(
            onPressed: onVlastni,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Zapsat vlastní stav'),
          ),
        ],
      ],
    );
  }
}

class _Popisek extends StatelessWidget {
  const _Popisek(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.overline.copyWith(color: context.palette.muted),
    );
  }
}
