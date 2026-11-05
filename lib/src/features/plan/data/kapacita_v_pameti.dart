import '../../orders/domain/entities/plan_klempirny.dart';
import '../domain/kapacita.dart';
import '../domain/prehled_planu.dart';

/// Kapacita dílen bez serveru - ukázková data a testy. Pravidla stejná jako
/// služba: ruční zařazení přebije tarif, ruční den přebije lidi.
mixin KapacitaVPameti {
  /// Výchozí lidé po pobočkách - ukázková data si je přepíšou.
  Map<String, List<ClovekKapacity>> get vychoziLideKapacity => const {};

  late final Map<String, List<ClovekKapacity>> lideKapacity = {
    for (final e in vychoziLideKapacity.entries) e.key: [...e.value],
  };
  final Map<String, List<RucniDenKapacity>> rucniDnyKapacity = {};
  int _dalsiNepritomnost = 1;

  Future<PrehledKapacity> nactiKapacitu(String pobocka) async =>
      PrehledKapacity(
        lide: [...?lideKapacity[pobocka]],
        dny: [...?rucniDnyKapacity[pobocka]],
      );

  void _upravCloveka(int id, ClovekKapacity Function(ClovekKapacity) uprava) {
    for (final lide in lideKapacity.values) {
      final i = lide.indexWhere((c) => c.id == id);
      if (i != -1) lide[i] = uprava(lide[i]);
    }
  }

  Future<void> zaradCloveka(int id, String? dilna) async {
    _upravCloveka(id, (c) => c.copyWith(prirazeno: () => dilna));
  }

  Future<void> pridejNepritomnost(int id, DateTime od, DateTime do_) async {
    _upravCloveka(
      id,
      (c) => c.copyWith(
        nepritomnosti: [
          ...c.nepritomnosti,
          NepritomnostCloveka(id: _dalsiNepritomnost++, od: od, do_: do_),
        ],
      ),
    );
  }

  Future<void> smazNepritomnost(int id) async {
    for (final lide in lideKapacity.values) {
      for (final (i, c) in lide.indexed) {
        lide[i] = c.copyWith(
          nepritomnosti: [
            for (final n in c.nepritomnosti)
              if (n.id != id) n,
          ],
        );
      }
    }
  }

  Future<void> ulozKapacituDne(
    String pobocka,
    DateTime den,
    Dilna dilna,
    int? aw,
  ) async {
    final dny = rucniDnyKapacity[pobocka] ??= [];
    dny.removeWhere((d) => d.den == den && d.dilna == dilna);
    if (aw != null) {
      dny.add(RucniDenKapacity(den: den, dilna: dilna, aw: aw));
      dny.sort((a, b) => a.den.compareTo(b.den));
    }
  }

  /// Kapacita po pobočkách pro přehled plánu.
  Map<String, Map<DateTime, Map<Dilna, KapacitaDne>>> kapacityVPameti(
    DateTime od,
    DateTime do_,
  ) => {
    for (final pobocka in {...lideKapacity.keys, ...rucniDnyKapacity.keys})
      pobocka: kapacityObdobi(
        lideKapacity[pobocka] ?? const [],
        rucniDnyKapacity[pobocka] ?? const [],
        od,
        do_,
      ),
  };
}
