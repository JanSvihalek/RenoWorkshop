import '../../domain/entities/zavada.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../fotodokumentace/domain/entities/fotka.dart';
import '../../../fotodokumentace/presentation/controllers/fotky_providers.dart';
import '../../../fotodokumentace/presentation/ziskani_fotek.dart';
import '../../domain/entities/dilensky_stav.dart';
import '../../domain/entities/plan_klempirny.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/order_actions_controller.dart';
import '../controllers/orders_providers.dart';
import 'okno_zapisu.dart';

/// Co uživatel vyplnil: stav z číselníku (u závady, úkonu mimo číselník
/// a dřív zapsaného vlastního stavu jejich název), a k tomu nepovinná
/// poznámka.
class VybranyStav {
  const VybranyStav({
    this.kod,
    this.nazev,
    this.poznamka,
    this.misto,
    this.fotkaMista,
  });

  final String? kod;
  final String? nazev;

  /// Na co se čeká, co se domluvilo.
  final String? poznamka;

  /// Kde vůz po tomhle kroku stojí. `null` = nechat, co tam je,
  /// prázdný text místo smaže.
  final String? misto;

  /// Fotka místa, kam technik vůz postavil. Nahraje se do kategorie
  /// Umístění vozu; `null` = nefotil.
  final Uint8List? fotkaMista;
}

/// Formulář pro přidání dílenského stavu.
///
/// Jedno okno: nahoře výběr stavu, pod ním poznámka, dole potvrzení.
/// Dřív se stav ukládal hned po klepnutí v seznamu a poznámka se musela
/// napsat dopředu — tedy dřív, než člověk věděl, k čemu ji píše.
/// [misto] je místo, kde vůz stojí teď - předvyplní se, ať ho technik
/// při každém kroku nepíše znovu. Vzhled je stejný jako u nové poznámky
/// ([OknoZapisu]).
Future<VybranyStav?> vyberStav(
  BuildContext context, {
  String? misto,
  required String spz,
  required String cisloZakazky,
  required String autor,

  /// Kód pořadače zakázky - nabídka stavů je podle něj
  /// ([nabidkaStavuProvider]).
  String? poradac,

  /// Zahájení úkonu z plánu - stav je předvybraný podle jeho typu.
  TypUkonu? ukon,

  /// Zahájení závady z Heliosu - krok se zapíše s tímhle názvem, stav se
  /// nevybírá.
  String? nazevZavady,
}) {
  return showDialog<VybranyStav>(
    context: context,
    builder: (_) => _PridatStavOkno(
      misto: misto,
      spz: spz,
      cisloZakazky: cisloZakazky,
      autor: autor,
      poradac: poradac,
      ukon: ukon,
      nazevZavady: nazevZavady,
    ),
  );
}

/// Hodnota v seznamu, která znamená „stav mimo číselník". Vlastní text
/// uživatel napsat nemůže (od 25. 11. jen stavy z databáze) - mimo
/// číselník je jen název závady, úkonu nebo dřív zapsaného stavu.
const _jiny = '__jiny__';

class _PridatStavOkno extends ConsumerStatefulWidget {
  const _PridatStavOkno({
    this.misto,
    required this.spz,
    required this.cisloZakazky,
    required this.autor,
    this.poradac,
    this.ukon,
    this.nazevZavady,
  });

  final String? nazevZavady;
  final String? poradac;
  final String? misto;
  final String spz;
  final String cisloZakazky;
  final String autor;
  final TypUkonu? ukon;

  @override
  ConsumerState<_PridatStavOkno> createState() => _PridatStavOknoState();
}

class _PridatStavOknoState extends ConsumerState<_PridatStavOkno> {
  /// Název kroku mimo číselník: závada, nebo úkon, jehož typ v číselníku
  /// stavů není.
  String? get _nazevMimo => widget.nazevZavady ?? widget.ukon?.nazev;

  final _poznamka = TextEditingController();
  late final _misto = TextEditingController(text: widget.misto ?? '');

  /// Vyfocené místo, dokud se stav neuloží.
  Uint8List? _fotka;

  /// Kód vybraného stavu, `_jiny` u vlastního, `null` dokud nic nevybral.
  String? _vybrany;

  @override
  void dispose() {
    _poznamka.dispose();
    _misto.dispose();
    super.dispose();
  }

  /// Vybraný stav, u zahájení úkonu jinak ten podle jeho typu. Typ, který
  /// v číselníku stavů není, se zapíše svým názvem.
  String? get _zvoleny {
    if (widget.nazevZavady != null) return _jiny;
    if (_vybrany != null) return _vybrany;
    final ukon = widget.ukon;
    final stavy = ref.read(nabidkaStavuProvider(widget.poradac)).valueOrNull;
    if (ukon == null || stavy == null) return null;
    return stavy.any((s) => s.kod == ukon.kod) ? ukon.kod : _jiny;
  }

  bool get _jeVlastni => _zvoleny == _jiny;

  /// Přidat jde, teprve když je co uložit.
  bool get _lzePridat =>
      _zvoleny != null && (!_jeVlastni || (_nazevMimo ?? '').isNotEmpty);

  void _potvrd() {
    if (!_lzePridat) return;
    final poznamka = _poznamka.text.trim();
    final misto = _misto.text.trim();

    Navigator.of(context).pop(
      VybranyStav(
        kod: _jeVlastni ? null : _zvoleny,
        nazev: _jeVlastni ? _nazevMimo : null,
        poznamka: poznamka.isEmpty ? null : poznamka,
        // Beze změny se místo neposílá - ať se u něj nepřepisuje čas
        // zápisu, když vůz zůstal stát.
        misto: misto == (widget.misto ?? '') ? null : misto,
        fotkaMista: _fotka,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nabidka = ref.watch(nabidkaStavuProvider(widget.poradac));

    return OknoZapisu(
      nadpis: switch (widget.nazevZavady ?? widget.ukon?.nazev) {
        final nazev? => 'Zahájit: $nazev',
        null => 'Přidat stav',
      },
      kam: 'do postupu zakázky',
      spz: widget.spz,
      cisloZakazky: widget.cisloZakazky,
      autor: widget.autor,
      potvrdit: widget.ukon == null && widget.nazevZavady == null
          ? 'Přidat'
          : 'Zahájit',
      onPotvrdit: _lzePridat ? _potvrd : null,
      obsah: [
        if (widget.nazevZavady == null) ...[
          const PopisekPole('STAV'),
          nabidka.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            // Bez nabídky stav přidat nejde - vlastní text se nezapisuje.
            error: (_, _) => const _NabidkaChybi(
              text: 'Nabídku stavů se nepodařilo načíst.',
            ),
            data: (stavy) => stavy.isEmpty
                ? const _NabidkaChybi(text: 'Číselník stavů je zatím prázdný.')
                : _VyberStavu(
                    stavy: stavy,
                    vybrany: _zvoleny,
                    // Úkon, jehož typ v číselníku není, má v nabídce svůj
                    // název - ať jde po přeložení zase vybrat.
                    nazevMimo:
                        _zvoleny == _jiny ||
                            (widget.ukon != null &&
                                !stavy.any((s) => s.kod == widget.ukon!.kod))
                        ? _nazevMimo
                        : null,
                    onZmena: (kod) => setState(() => _vybrany = kod),
                  ),
          ),
        ],

        const SizedBox(height: Insets.base),
        // Vůz se hýbe právě tehdy, když se mění, co se s ním děje -
        // proto se na místo ptáme u každého kroku.
        const PopisekPole('KDE VŮZ STOJÍ'),
        PoleZapisu(
          poleKey: const Key('stav-misto'),
          controller: _misto,
          napoveda: 'Např. stání 4, lakovna',
          maxDelka: 60,
        ),
        const SizedBox(height: Insets.xs),
        _FotkaMista(
          fotka: _fotka,
          onVyfotit: _vyfotMisto,
          onSmazat: () => setState(() => _fotka = null),
        ),

        const SizedBox(height: Insets.base),
        const PopisekPole('POZNÁMKA (NEPOVINNÁ)'),
        PoleZapisu(
          controller: _poznamka,
          napoveda: 'Např. čeká na díl',
          maxDelka: 500,
          minLines: 2,
          maxLines: 4,
          sDiktovanim: true,
        ),
      ],
    );
  }

  /// Fotka místa - na velkém parkovišti řekne víc než „stání 4".
  Future<void> _vyfotMisto() async {
    final fotka = await ref.read(ziskaniFotekProvider).jednaFotka(context);
    if (fotka != null && mounted) setState(() => _fotka = fotka);
  }
}

/// Nepovinná fotka místa: tlačítko, po vyfocení náhled s křížkem.
class _FotkaMista extends StatelessWidget {
  const _FotkaMista({
    required this.fotka,
    required this.onVyfotit,
    required this.onSmazat,
  });

  final Uint8List? fotka;
  final VoidCallback onVyfotit;
  final VoidCallback onSmazat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final vyfoceno = fotka;

    if (vyfoceno == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('vyfotit-misto'),
          onPressed: onVyfotit,
          icon: const Icon(Icons.add_a_photo_outlined, size: 20),
          label: const Text('Vyfotit místo'),
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
        ),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.input),
          child: Image.memory(
            vyfoceno,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            cacheWidth: 168,
          ),
        ),
        const SizedBox(width: Insets.base),
        Expanded(
          child: Text(
            'Fotka místa se nahraje po uložení stavu.',
            style: AppTextStyles.metaSmall.copyWith(color: palette.muted),
          ),
        ),
        IconButton(
          key: const Key('zahodit-fotku-mista'),
          tooltip: 'Zahodit fotku',
          onPressed: onSmazat,
          icon: Icon(Icons.close_rounded, color: palette.muted),
        ),
      ],
    );
  }
}

class _VyberStavu extends StatelessWidget {
  const _VyberStavu({
    required this.stavy,
    required this.vybrany,
    required this.onZmena,
    this.nazevMimo,
  });

  final List<NabidkaStavu> stavy;
  final String? vybrany;
  final ValueChanged<String?> onZmena;

  /// Název kroku mimo číselník (úkon, dřív zapsaný vlastní stav) - v nabídce
  /// je navíc. `null` = nabídka jen z číselníku.
  final String? nazevMimo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      decoration: vzhledRamecku(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: vybrany,
          isExpanded: true,
          hint: Text(
            'Vyberte stav',
            style: AppTextStyles.cardBody.copyWith(
              fontSize: 15,
              color: palette.muted,
            ),
          ),
          borderRadius: BorderRadius.circular(Radii.input),
          dropdownColor: palette.card,
          style: AppTextStyles.cardBody.copyWith(
            fontSize: 15,
            color: palette.text,
          ),
          items: [
            for (final stav in stavy)
              DropdownMenuItem(value: stav.kod, child: Text(stav.nazev)),
            if (nazevMimo case final nazev?)
              DropdownMenuItem(value: _jiny, child: Text(nazev)),
          ],
          onChanged: onZmena,
        ),
      ),
    );
  }
}

class _NabidkaChybi extends StatelessWidget {
  const _NabidkaChybi({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.cardBody.copyWith(color: context.palette.muted),
    );
  }
}

/// Nový dílenský stav u zakázky - okno, zápis, fotka místa a hláška.
/// Z detailu zakázky i z plánu klempírny (průběh na dílně).
Future<void> pridatStavZakazce(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder order, {
  TypUkonu? ukon,
  Zavada? zavada,
  RucniUkon? rucniUkon,
}) async {
  // Místo se předvyplní tím, kde vůz stojí teď - technik ho tak
  // nepíše u každého kroku znovu.
  final vybrany = await vyberStav(
    context,
    misto: order.bay,
    spz: order.licensePlate,
    cisloZakazky: order.id,
    autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
    poradac: order.poradac?.kod,
    ukon: ukon,
    nazevZavady: zavada?.nazevKroku ?? rucniUkon?.nazev,
  );
  if (vybrany == null || !context.mounted) return;

  final hotovo = await ref
      .read(orderActionsProvider.notifier)
      .pridejStav(
        order.id,
        kod: vybrany.kod,
        nazev: vybrany.nazev,
        poznamka: vybrany.poznamka,
        misto: vybrany.misto,
        zavadaId: zavada?.id,
        ukonId: rucniUkon?.id,
      );

  if (!hotovo) return;

  // Fotka až po uložení stavu - nahrává se stejnou frontou jako fotky
  // z příjmu, takže výpadek wi-fi ji neztratí.
  final fotka = vybrany.fotkaMista;
  if (fotka != null) {
    await ref.read(nahravaniFotekProvider(order.id).notifier).pridej(
      KategorieFotky.umisteni,
      [fotka],
    );
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${order.id} · stav přidán')));
  }
}

/// Úprava zapsaného stavu, když se někdo ukliknul: jiný stav z číselníku,
/// poznámka. Dřív zapsaný vlastní stav jde nechat, nový napsat ne. Čas a autor zůstávají, u stavu přibude
/// „upraveno". Krok zahájený u závady nebo ručního úkonu nese jejich název,
/// u něj jde upravit jen poznámka.
Future<void> upravitStavZakazky(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder order,
  DilenskyStav stav,
) async {
  final id = stav.id;
  if (id == null) return;
  final vybrany = await showDialog<VybranyStav>(
    context: context,
    builder: (_) => _UpravitStavOkno(order: order, stav: stav),
  );
  if (vybrany == null || !context.mounted) return;

  final hotovo = await ref
      .read(orderActionsProvider.notifier)
      .upravStav(
        order.id,
        id,
        kod: vybrany.kod,
        nazev: vybrany.nazev,
        poznamka: vybrany.poznamka,
      );
  if (hotovo && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${order.id} · stav upraven')));
  }
}

class _UpravitStavOkno extends ConsumerStatefulWidget {
  const _UpravitStavOkno({required this.order, required this.stav});

  final ServiceOrder order;
  final DilenskyStav stav;

  @override
  ConsumerState<_UpravitStavOkno> createState() => _UpravitStavOknoState();
}

class _UpravitStavOknoState extends ConsumerState<_UpravitStavOkno> {
  late final _poznamka = TextEditingController(
    text: widget.stav.poznamka ?? '',
  );

  /// Kód vybraného stavu, `_jiny` u vlastního; `null` = jak byl.
  String? _vybrany;

  bool get _jenPoznamka => widget.stav.jeKrokZavady;

  /// Vybraný stav, jinak ten původní - i když v nabídce pořadače není
  /// (vyřazený, nebo zapsaný dřív): je v ní navíc ([_sPuvodnim]), ať se
  /// úpravou poznámky nepřevede na vlastní text a neztratí kód.
  String get _zvoleny => _vybrany ?? widget.stav.kod ?? _jiny;

  /// Nabídka pořadače a k ní původní stav, když v ní chybí.
  List<NabidkaStavu> _sPuvodnim(List<NabidkaStavu> stavy) {
    final kod = widget.stav.kod;
    if (kod == null || stavy.any((s) => s.kod == kod)) return stavy;
    return [...stavy, NabidkaStavu(kod: kod, nazev: widget.stav.nazev)];
  }

  bool get _jeVlastni => _zvoleny == _jiny;

  /// Mimo číselník jde nechat jen původní vlastní text.
  bool get _lzeUlozit => _jenPoznamka || !_jeVlastni || widget.stav.jeVlastni;

  @override
  void dispose() {
    _poznamka.dispose();
    super.dispose();
  }

  void _potvrd() {
    if (!_lzeUlozit) return;
    Navigator.of(context).pop(
      VybranyStav(
        kod: _jenPoznamka || _jeVlastni ? null : _zvoleny,
        nazev: _jenPoznamka || !_jeVlastni ? null : widget.stav.nazev,
        // Prázdný text poznámku smaže.
        poznamka: _poznamka.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nabidka = ref.watch(nabidkaStavuProvider(widget.order.poradac?.kod));
    final stav = widget.stav;

    return OknoZapisu(
      nadpis: _jenPoznamka ? 'Upravit: ${stav.nazev}' : 'Upravit stav',
      kam: 'v postupu zakázky',
      spz: widget.order.licensePlate,
      cisloZakazky: widget.order.id,
      autor: stav.autor ?? 'neznámý',
      potvrdit: 'Uložit',
      potvrditKey: const Key('upravit-stav-ulozit'),
      onPotvrdit: _lzeUlozit ? _potvrd : null,
      obsah: [
        if (!_jenPoznamka) ...[
          const PopisekPole('STAV'),
          nabidka.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const _NabidkaChybi(
              text: 'Nabídku stavů se nepodařilo načíst.',
            ),
            data: (stavy) => _VyberStavu(
              stavy: _sPuvodnim(stavy),
              vybrany: _zvoleny,
              nazevMimo: stav.jeVlastni ? stav.nazev : null,
              onZmena: (kod) => setState(() => _vybrany = kod),
            ),
          ),
        ],
        const SizedBox(height: Insets.base),
        const PopisekPole('POZNÁMKA (NEPOVINNÁ)'),
        PoleZapisu(
          poleKey: const Key('upravit-stav-poznamka'),
          controller: _poznamka,
          napoveda: 'Např. čeká na díl',
          maxDelka: 500,
          minLines: 2,
          maxLines: 4,
          sDiktovanim: true,
        ),
      ],
    );
  }
}
