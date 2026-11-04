import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Odkaz na zavolání - jen číslice a plus, u víc čísel to první.
Uri? odkazTelefon(String? telefon) {
  final cislo = (telefon ?? '')
      .split(RegExp(r'[,;]'))
      .first
      .replaceAll(RegExp(r'[^\d+]'), '');
  return RegExp(r'\d').hasMatch(cislo) ? Uri(scheme: 'tel', path: cislo) : null;
}

/// Odkaz na e-mail - u víc adres ta první.
Uri? odkazEmail(String? email) {
  final adresa = (email ?? '').split(RegExp(r'[,;]')).first.trim();
  return adresa.contains('@') ? Uri(scheme: 'mailto', path: adresa) : null;
}

/// Otevře odkaz v telefonu nebo poště. `false` = zařízení to neumí (tablet
/// bez SIM, počítač bez poštovního klienta).
final otevritOdkazProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (odkaz) => launchUrl(odkaz, mode: LaunchMode.externalApplication),
);
