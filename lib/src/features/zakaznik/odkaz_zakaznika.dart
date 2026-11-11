/// Odkaz pro zákazníka na průběh zakázky - stejné jako okno na webu
/// (web/src/zakazky/OknoOdkazuZakaznika.tsx). Vytváří se ručně: bez odkazu
/// zákazník průběh nevidí ani po zadání SPZ a čísla zakázky. Zrušením
/// přestane fungovat odkaz i SPZ s číslem.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/date_formats.dart';
import '../../core/utils/kontakt_odkazy.dart';
import '../orders/domain/repositories/service_order_repository.dart';
import '../orders/presentation/controllers/orders_providers.dart';

class OdkazZakaznika {
  const OdkazZakaznika({
    required this.url,
    required this.vytvoreno,
    this.vytvoril,
  });

  final String? url;
  final DateTime vytvoreno;
  final String? vytvoril;

  static OdkazZakaznika? fromJson(Object? json) => switch (json) {
    {'createdAt': final String vytvoreno} => OdkazZakaznika(
      url: (json as Map)['url'] as String?,
      vytvoreno: DateTime.tryParse(vytvoreno) ?? DateTime(2026),
      vytvoril: json['createdBy'] as String?,
    ),
    _ => null,
  };
}

/// `GET/POST/DELETE /orders/{id}/customer-link` - implementuje ho stejná
/// služba jako zakázky.
abstract interface class OdkazZakaznikaDataSource {
  Future<OdkazZakaznika?> nactiOdkazZakaznika(String orderId);
  Future<OdkazZakaznika> vytvorOdkazZakaznika(String orderId);
  Future<void> zrusOdkazZakaznika(String orderId);
}

OdkazZakaznikaDataSource _zdroj(WidgetRef ref) {
  final zdroj = ref.read(serviceOrderDataSourceProvider);
  if (zdroj is OdkazZakaznikaDataSource) {
    return zdroj as OdkazZakaznikaDataSource;
  }
  throw const ServiceOrderException(
    'V ukázkových datech odkaz pro zákazníka není.',
  );
}

/// Otevře okno s odkazem zakázky.
Future<void> ukazOdkazZakaznika(
  BuildContext context, {
  required String orderId,
  required bool smiZapisovat,
}) => showDialog<void>(
  context: context,
  builder: (_) => _OknoOdkazu(orderId: orderId, smiZapisovat: smiZapisovat),
);

class _OknoOdkazu extends ConsumerStatefulWidget {
  const _OknoOdkazu({required this.orderId, required this.smiZapisovat});

  final String orderId;
  final bool smiZapisovat;

  @override
  ConsumerState<_OknoOdkazu> createState() => _OknoOdkazuState();
}

class _OknoOdkazuState extends ConsumerState<_OknoOdkazu> {
  bool _nacita = true;
  bool _pracuje = false;
  bool _rusi = false;
  String? _chyba;
  OdkazZakaznika? _odkaz;

  @override
  void initState() {
    super.initState();
    _proved(() async {
      _odkaz = await _zdroj(ref).nactiOdkazZakaznika(widget.orderId);
    });
  }

  Future<void> _proved(Future<void> Function() akce) async {
    setState(() {
      _pracuje = true;
      _chyba = null;
    });
    try {
      await akce();
    } on ServiceOrderException catch (chyba) {
      _chyba = chyba.message;
    } finally {
      if (mounted) {
        setState(() {
          _pracuje = false;
          _nacita = false;
        });
      }
    }
  }

  void _oznam(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final odkaz = _odkaz;
    final maly = AppTextStyles.metaSmall.copyWith(color: palette.muted);
    final text = AppTextStyles.cardBody.copyWith(color: palette.text);

    final List<Widget> obsah;
    if (_nacita) {
      obsah = [const Center(child: CircularProgressIndicator())];
    } else if (odkaz == null && _chyba != null) {
      obsah = [Text(_chyba!, style: text)];
    } else if (odkaz == null) {
      obsah = [
        Text(
          'Zákazník zatím průběh zakázky nevidí. Po vytvoření odkazu ho uvidí '
          'přes odkaz, nebo po zadání SPZ a čísla zakázky na stránce pro '
          'zákazníky. Odkaz se zatím nikam neposílá.',
          style: text,
        ),
        const SizedBox(height: Insets.lg),
        if (widget.smiZapisovat)
          FilledButton(
            key: const Key('odkaz-vytvorit'),
            onPressed: _pracuje
                ? null
                : () => _proved(() async {
                    _odkaz = await _zdroj(
                      ref,
                    ).vytvorOdkazZakaznika(widget.orderId);
                    if (mounted) _oznam('Odkaz pro zákazníka je vytvořený');
                  }),
            child: const Text('Vytvořit odkaz'),
          )
        else
          Text('Odkaz vytvoří ten, kdo má k zakázce zápis.', style: maly),
      ];
    } else {
      final url = odkaz.url;
      obsah = [
        Text(
          'Zákazník vidí průběh zakázky přes tenhle odkaz, nebo po zadání SPZ '
          'a čísla zakázky.',
          style: text,
        ),
        if (url != null) ...[
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(Radii.input),
              border: Border.all(color: palette.hairline2),
            ),
            child: SelectableText(
              url,
              key: const Key('odkaz-adresa'),
              style: AppTextStyles.monoLabel.copyWith(
                color: palette.text,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            children: [
              OutlinedButton.icon(
                key: const Key('odkaz-kopirovat'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  _oznam('Odkaz zkopírován');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Kopírovat'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.read(otevritOdkazProvider)(Uri.parse(url)),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Otevřít'),
              ),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        Text(
          'Vytvořeno ${AppDateFormat.date(odkaz.vytvoreno)}, '
          '${AppDateFormat.time(odkaz.vytvoreno)}'
          '${odkaz.vytvoril != null ? ' · ${odkaz.vytvoril}' : ''}. '
          'Po ukončení zakázky přestane fungovat.',
          style: maly,
        ),
        if (widget.smiZapisovat) ...[
          const SizedBox(height: Insets.sm),
          if (_rusi)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Insets.sm,
              children: [
                Text(
                  'Zrušit odkaz? Zákazník přestane průběh vidět.',
                  style: maly,
                ),
                TextButton(
                  onPressed: () => setState(() => _rusi = false),
                  child: const Text('Ne'),
                ),
                FilledButton(
                  key: const Key('odkaz-zrusit-ano'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  onPressed: _pracuje
                      ? null
                      : () => _proved(() async {
                          await _zdroj(ref).zrusOdkazZakaznika(widget.orderId);
                          _odkaz = null;
                          _rusi = false;
                          if (mounted) {
                            _oznam('Odkaz je zrušený, zákazník průběh nevidí');
                          }
                        }),
                  child: const Text('Zrušit odkaz'),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('odkaz-zrusit'),
                onPressed: () => setState(() => _rusi = true),
                child: const Text('Zrušit odkaz'),
              ),
            ),
        ],
      ];
    }

    return AlertDialog(
      key: const Key('okno-odkazu-zakaznika'),
      title: const Text('Odkaz pro zákazníka'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Zakázka ${widget.orderId}', style: maly),
              const SizedBox(height: Insets.md),
              ...obsah,
              if (_chyba != null && odkaz != null) ...[
                const SizedBox(height: Insets.sm),
                Text(_chyba!, style: maly.copyWith(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zavřít'),
        ),
      ],
    );
  }
}
