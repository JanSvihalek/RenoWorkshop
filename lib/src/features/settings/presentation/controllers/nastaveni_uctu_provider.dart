import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/presentation/controllers/orders_providers.dart';
import '../../../plan/presentation/plan_providers.dart';
import '../../data/nastaveni_uctu_data_source.dart';
import '../../domain/nastaveni_uctu.dart';
import 'nastaveni_controller.dart';

/// Nastavení na účtu - napojí telefon na `/me/settings` po přihlášení
/// (sleduje ho kořen appky).
///
/// Po přihlášení se nastavení z účtu načte a přepíše to v telefonu. Je-li
/// účet ještě prázdný, nahraje se tam to z telefonu - nikdo o svůj filtr
/// nepřijde. Pak se každá změna pošle na účet, ale jen klíče, které se
/// změnily. Když služba neodpoví, platí dál nastavení v telefonu.
final nastaveniUctuProvider = Provider<void>((ref) {
  final ja = ref.watch(currentEmployeeProvider);
  final zdroj = ref.watch(serviceOrderDataSourceProvider);
  if (ja == null || zdroj is! NastaveniUctuDataSource) return;
  final napojeni = _Napojeni(ref, zdroj as NastaveniUctuDataSource);
  ref.onDispose(napojeni.zrus);
  napojeni.spust();
});

/// Kliká-li se ve filtru, pošle se až poslední stav.
const _prodleva = Duration(milliseconds: 800);

class _Napojeni {
  _Napojeni(this._ref, this._zdroj);

  final Ref _ref;
  final NastaveniUctuDataSource _zdroj;

  /// Co je na účtu - z toho se berou klíče, kterým appka nerozumí.
  Map<String, Object?> _naUctu = const {};
  bool _pripraveno = false;
  bool _zruseno = false;
  Timer? _casovac;

  PohledPlanu _pohled() => PohledPlanu(
    pobocka: _ref.read(planPobockaProvider),
    tydnu: _ref.read(planTydnuProvider),
    filtr: _ref.read(planFiltrProvider),
    kodLaku: _ref.read(planKodLakuProvider),
    stavPlanu: _ref.read(planStavPlanuProvider),
  );

  Map<String, Object?> _aktualni() =>
      castiAplikace(_ref.read(nastaveniProvider), _pohled(), _naUctu);

  void spust() {
    // Posluchače hned - po načtení z účtu by se už přidat nedaly.
    _ref
      ..listen(nastaveniProvider, (_, _) => _naplanuj())
      ..listen(planPobockaProvider, (_, _) => _naplanuj())
      ..listen(planTydnuProvider, (_, _) => _naplanuj())
      ..listen(planFiltrProvider, (_, _) => _naplanuj())
      ..listen(planKodLakuProvider, (_, _) => _naplanuj())
      ..listen(planStavPlanuProvider, (_, _) => _naplanuj());
    unawaited(_nacti());
  }

  Future<void> _nacti() async {
    try {
      final ucet = await _zdroj.nactiNastaveniUctu();
      if (_zruseno) return;
      if (ucet.isEmpty) {
        // Účet je prázdný - nahrát to z telefonu.
        final zTelefonu = _aktualni();
        await _zdroj.ulozNastaveniUctu(zTelefonu);
        _naUctu = zTelefonu;
      } else {
        _naUctu = ucet;
        _pouzij(ucet);
      }
      _pripraveno = true;
    } catch (_) {
      // Služba neodpověděla - platí nastavení v telefonu.
    }
  }

  void _pouzij(Map<String, Object?> ucet) {
    final ovladani = _ref.read(nastaveniProvider.notifier);
    ovladani.prevezmiZUctu(nastaveniZUctu(_ref.read(nastaveniProvider), ucet));
    final planner = ucet['planner'];
    final pohled = pohledZUctu(
      planner is Map<String, Object?> ? planner : null,
      _ref.read(planFiltrProvider),
    );
    _ref.read(planPobockaProvider.notifier).state = pohled.pobocka;
    _ref.read(planTydnuProvider.notifier).state = pohled.tydnu;
    _ref.read(planFiltrProvider.notifier).state = pohled.filtr;
    _ref.read(planKodLakuProvider.notifier).state = pohled.kodLaku;
    _ref.read(planStavPlanuProvider.notifier).state = pohled.stavPlanu;
  }

  void _naplanuj() {
    if (!_pripraveno || _zruseno) return;
    _casovac?.cancel();
    _casovac = Timer(_prodleva, _posli);
  }

  Future<void> _posli() async {
    final zmena = zmenyNastaveni(_naUctu, _aktualni());
    if (zmena.isEmpty) return;
    try {
      await _zdroj.ulozNastaveniUctu(zmena);
      _naUctu = {..._naUctu, ...zmena};
    } catch (_) {
      // Neposlalo se - zůstane v telefonu, příští změna to zkusí znovu.
    }
  }

  void zrus() {
    _zruseno = true;
    _casovac?.cancel();
  }
}
