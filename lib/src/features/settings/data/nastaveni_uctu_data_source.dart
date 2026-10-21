/// Nastavení na účtu (`GET/PATCH /me/settings`) - implementuje ho stejná
/// služba jako zakázky. Ukázková data ho nemají: v nich se nic na účet
/// neukládá.
abstract interface class NastaveniUctuDataSource {
  Future<Map<String, Object?>> nactiNastaveniUctu();

  /// Změní jen poslané klíče, `null` klíč smaže.
  Future<void> ulozNastaveniUctu(Map<String, Object?> zmena);
}
