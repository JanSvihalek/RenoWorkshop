import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dimens.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/obalka_klice.dart';
import '../../domain/entities/service_order.dart';
import '../controllers/order_actions_controller.dart';
import 'detail_cards.dart';
import 'okno_zapisu.dart';

/// Obálka s klíčem od vozu v aplikaci: okno pro přiřazení a karta do
/// příjmu. Co obálka je, viz [ObalkaKlice].

/// Otevře skener v režimu obálek a vrátí kód naskenované obálky, nebo
/// `null`, když technik skener zavřel.
typedef SkenujObalku = Future<String?> Function();

/// Předpona obálek pobočky zakázky (`BSL` -> `KBSL-`) - technikovi pak
/// stačí napsat jen číslo. `null` = pobočka zakázky není známá.
String? predponaObalky(ServiceOrder zakazka) {
  final pobocka = zakazka.pobockaObalek?.trim().toUpperCase();
  return pobocka != null && pobockyObalek.containsKey(pobocka)
      ? 'K$pobocka-'
      : null;
}

/// Kód obálky z toho, co technik napsal: celý kód, nebo jen číslo, když
/// je známá pobočka zakázky.
String? kodZNapsaneho(String text, ServiceOrder zakazka) {
  final cele = kodObalky(text);
  if (cele != null) return cele;
  final predpona = predponaObalky(zakazka);
  final cislo = text.trim();
  if (predpona == null || !RegExp(r'^\d{1,3}$').hasMatch(cislo)) return null;
  return kodObalky('$predpona$cislo');
}

/// Celý postup přiřazení: okno, přiřazení, případná otázka (obálka jiné
/// zakázky nebo pobočky) a potvrzení.
///
/// [ukazChybu] - obrazovka, která chyby z [orderActionsProvider] sama
/// neukazuje (příjem). Detail zakázky je ukazuje, tam by byly dvakrát.
Future<void> zmenObalku(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder zakazka, {
  SkenujObalku? onSkenuj,
  bool ukazChybu = false,
}) async {
  final zapis = _Zapis.z(context, ref);
  final kod = await showDialog<String>(
    context: context,
    builder: (_) => _OknoObalky(
      zakazka: zakazka,
      autor: ref.read(currentEmployeeProvider)?.displayName ?? 'Dílna',
      onSkenuj: onSkenuj,
    ),
  );
  if (kod == null) return;
  await zapis.prirad(zakazka.id, kod, ukazChybu: ukazChybu);
}

/// Přiřadí obálku (třeba rovnou naskenovanou); když se server zeptá,
/// zeptá se technika a po potvrzení přiřadí stejně.
Future<void> priradObalku(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  String kod, {
  bool ukazChybu = false,
}) => _Zapis.z(context, ref).prirad(orderId, kod, ukazChybu: ukazChybu);

/// Uvolní obálku zakázky - po potvrzení, klíč z ní odešel jinak než se
/// zákazníkem (po skončení zakázky v Heliosu se uvolní sama).
Future<void> uvolnitObalku(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder zakazka, {
  bool ukazChybu = false,
}) async {
  final kod = zakazka.obalka?.kod;
  if (kod == null) return;
  final zapis = _Zapis.z(context, ref);
  final ano = await zapis.potvrd(
    nadpis: 'Uvolnit obálku $kod?',
    text:
        'Obálka bude volná pro jiný vůz. Po ukončení zakázky v Heliosu '
        'se uvolní sama - ručně jen když klíč z obálky odešel jinak.',
    tlacitko: 'Uvolnit',
    klic: const Key('obalka-uvolnit-potvrdit'),
  );
  if (!ano) return;

  if (await zapis.akce.uvolniObalku(zakazka.id)) {
    zapis.zprava('Obálka $kod je volná.');
  } else if (ukazChybu) {
    zapis.zprava('Obálku se nepodařilo uvolnit. Zkuste to znovu.');
  }
}

/// Co zápis obálky potřebuje i po čekání na server. Detail zakázky se
/// po změně zakázky přestaví a původní `context` i `ref` přestanou
/// platit - hlášky a otázky proto jdou přes navigátor a messenger
/// vzaté předem.
class _Zapis {
  _Zapis._(this.akce, this.navigator, this.messenger);

  factory _Zapis.z(BuildContext context, WidgetRef ref) => _Zapis._(
    ref.read(orderActionsProvider.notifier),
    Navigator.of(context),
    ScaffoldMessenger.of(context),
  );

  final OrderActionsController akce;
  final NavigatorState navigator;
  final ScaffoldMessengerState messenger;

  void zprava(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> potvrd({
    required String nadpis,
    required String text,
    required String tlacitko,
    required Key klic,
  }) async {
    if (!navigator.mounted) return false;
    final ano = await showDialog<bool>(
      context: navigator.context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(nadpis),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            key: klic,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tlacitko),
          ),
        ],
      ),
    );
    return ano == true;
  }

  Future<void> prirad(
    String orderId,
    String kod, {
    required bool ukazChybu,
  }) async {
    var vysledek = await akce.priradObalku(orderId, kod);

    final otazka = vysledek.otazka;
    if (otazka != null) {
      final ano = await potvrd(
        nadpis: 'Obálka $kod',
        text: otazka,
        tlacitko: 'Přiřadit',
        klic: const Key('obalka-prepsat'),
      );
      if (!ano) return;
      vysledek = await akce.priradObalku(orderId, kod, prepsat: true);
    }

    if (vysledek.hotovo) {
      zprava('Klíč je v obálce $kod.');
      await HapticFeedback.lightImpact();
    } else if (ukazChybu && vysledek.chyba != null) {
      zprava(vysledek.chyba!);
    }
  }
}

/// Okno obálky: naskenovat, nebo napsat číslo. Vrací kód obálky.
/// Vzhled jako nová poznámka ([OknoZapisu]).
class _OknoObalky extends StatefulWidget {
  const _OknoObalky({
    required this.zakazka,
    required this.autor,
    required this.onSkenuj,
  });

  final ServiceOrder zakazka;
  final String autor;
  final SkenujObalku? onSkenuj;

  @override
  State<_OknoObalky> createState() => _OknoObalkyState();
}

class _OknoObalkyState extends State<_OknoObalky> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String? get _kod => kodZNapsaneho(_text.text, widget.zakazka);

  Future<void> _skenuj() async {
    final kod = await widget.onSkenuj?.call();
    if (kod != null && mounted) Navigator.of(context).pop(kod);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final soucasna = widget.zakazka.obalka;
    final kod = _kod;
    final napsano = _text.text.trim().isNotEmpty;
    final predpona = predponaObalky(widget.zakazka);
    final drobne = AppTextStyles.metaSmall.copyWith(color: palette.muted);

    return OknoZapisu(
      nadpis: 'Obálka s klíčem',
      kam: 'k zakázce',
      spz: widget.zakazka.licensePlate,
      cisloZakazky: widget.zakazka.id,
      autor: widget.autor,
      potvrdit: 'Přiřadit',
      potvrditKey: const Key('obalka-priradit'),
      onPotvrdit: kod == null || kod == soucasna?.kod
          ? null
          : () => Navigator.of(context).pop(kod),
      obsah: [
        if (widget.onSkenuj != null) ...[
          SizedBox(
            height: Sizes.ctaHeight,
            child: FilledButton.icon(
              key: const Key('obalka-skenovat'),
              onPressed: _skenuj,
              style: FilledButton.styleFrom(
                backgroundColor: context.isDarkMode
                    ? AppColors.accent
                    : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                'Naskenovat obálku',
                style: AppTextStyles.buttonLabel,
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
        ],
        PopisekPole(
          widget.onSkenuj == null ? 'ČÍSLO OBÁLKY' : 'NEBO NAPIŠTE ČÍSLO',
        ),
        PoleZapisu(
          poleKey: const Key('obalka-kod'),
          controller: _text,
          napoveda: predpona == null ? 'Např. KBSL-023' : 'Např. 23',
          maxDelka: 12,
          autofocus: widget.onSkenuj == null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          !napsano
              ? (predpona == null
                    ? 'Kód je na štítku obálky, třeba KBSL-023.'
                    : 'Stačí číslo, předpona $predpona se doplní.')
              : kod == null
              ? 'Tohle není kód obálky - má tvar KBSL-023.'
              : kod == soucasna?.kod
              ? 'Tahle obálka už u zakázky je.'
              : 'Přiřadí se obálka $kod.',
          key: const Key('obalka-napoveda'),
          style: napsano && kod == null
              ? drobne.copyWith(color: AppColors.danger)
              : drobne,
        ),
      ],
    );
  }
}

/// Obálka s klíčem jako karta - v příjmu, kde se klíč do obálky dává.
class ObalkaKarta extends ConsumerWidget {
  const ObalkaKarta({super.key, required this.zakazka, this.onSkenuj});

  final ServiceOrder zakazka;
  final SkenujObalku? onSkenuj;

  Future<void> _skenuj(BuildContext context, WidgetRef ref) async {
    final kod = await onSkenuj?.call();
    if (kod == null || !context.mounted) return;
    await priradObalku(context, ref, zakazka.id, kod, ukazChybu: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final obalka = zakazka.obalka;
    final kdy = obalka?.prirazilKdo;

    return DetailCard(
      key: const Key('obalka-karta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('OBÁLKA S KLÍČEM'),
          const SizedBox(height: Insets.base),
          if (obalka == null) ...[
            Text(
              'Vložte klíč do volné obálky a naskenujte její QR kód.',
              style: AppTextStyles.cardBody.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Insets.base),
            if (onSkenuj != null)
              SizedBox(
                height: Sizes.ctaHeight,
                child: FilledButton.icon(
                  key: const Key('obalka-karta-skenovat'),
                  onPressed: () => _skenuj(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.isDarkMode
                        ? AppColors.accent
                        : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    'Naskenovat obálku',
                    style: AppTextStyles.buttonLabel,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('obalka-karta-rucne'),
                onPressed: () => zmenObalku(
                  context,
                  ref,
                  zakazka,
                  onSkenuj: onSkenuj,
                  ukazChybu: true,
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: const Text('Zadat číslo ručně'),
              ),
            ),
          ] else
            Row(
              children: [
                Icon(Icons.key_rounded, color: palette.muted2),
                const SizedBox(width: Insets.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obalka.kod,
                        style: AppTextStyles.sectionTitle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      Text(
                        [
                          obalka.nazevPobocky,
                          if (kdy != null && kdy.isNotEmpty) 'vložil $kdy',
                        ].where((t) => t.isNotEmpty).join(' · '),
                        style: AppTextStyles.metaSmall.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('obalka-karta-uvolnit'),
                  onPressed: () =>
                      uvolnitObalku(context, ref, zakazka, ukazChybu: true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                  ),
                  child: const Text('Uvolnit'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
