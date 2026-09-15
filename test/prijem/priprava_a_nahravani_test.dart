import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:renoworkshop/src/features/orders/presentation/controllers/orders_providers.dart';
import 'package:renoworkshop/src/features/prijem/data/fotky_data_source.dart';
import 'package:renoworkshop/src/features/prijem/domain/entities/fotka.dart';
import 'package:renoworkshop/src/features/prijem/presentation/controllers/prijem_providers.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/prijem_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/ulozeni_do_zarizeni.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';

import '../helpers/fake_service_order_data_source.dart';

Uint8List jpeg({int sirka = 40, int vyska = 20}) =>
    img.encodeJpg(img.Image(width: sirka, height: vyska));

void main() {
  group('hledání zakázky podle SPZ', () {
    final zakazky = [
      buildOrderDto(
        id: 'ZK-1',
        licensePlate: '2BK 9485',
        receivedAt: '2026-09-01T08:00:00',
      ).toDomain(),
      buildOrderDto(
        id: 'ZK-2',
        licensePlate: '2BK 9485',
        receivedAt: '2026-09-10T08:00:00',
      ).toDomain(),
      buildOrderDto(id: 'ZK-3', licensePlate: '8AB 4721').toDomain(),
    ];

    test('najde bez ohledu na mezery, pomlčky a velikost písmen', () {
      expect(zakazkyPodleSpz(zakazky, '2bk-9485').map((z) => z.id), [
        'ZK-2',
        'ZK-1',
      ]);
    });

    test('nejnovější příjem je první', () {
      expect(zakazkyPodleSpz(zakazky, '2BK').first.id, 'ZK-2');
    });

    test('pod tři znaky nehledá', () {
      expect(zakazkyPodleSpz(zakazky, '2B'), isEmpty);
    });
  });

  test('jméno fotky v telefonu nese zakázku, kategorii a čas', () {
    expect(
      nazevFotkyVZarizeni(
        'Z121/26 0123',
        KategorieFotky.poskozeni,
        DateTime(2026, 9, 15, 10, 30, 12, 45),
      ),
      'Z121-26-0123_poskozeni_20260915-103012-045',
    );
  });

  group('příprava fotky', () {
    test('velkou fotku zmenší na 2000 px a vrátí JPEG', () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 4000, height: 3000)),
      );

      final vysledek = pripravFotku(png)!;
      final nactena = img.decodeJpg(vysledek)!;

      // Galerie umí vrátit PNG - server bere jen JPEG.
      expect(vysledek.sublist(0, 3), [0xff, 0xd8, 0xff]);
      expect(nactena.width, nejdelsiStranaFotky);
      expect(nactena.height, 1500);
    });

    test('fotku na výšku zmenší podle výšky', () {
      final vysledek = pripravFotku(
        Uint8List.fromList(img.encodeJpg(img.Image(width: 1000, height: 3000))),
      )!;
      final nactena = img.decodeJpg(vysledek)!;
      expect(nactena.height, nejdelsiStranaFotky);
    });

    test('nesmysl vrátí null, ne výjimku', () {
      expect(pripravFotku(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  test('fotka neznámé kategorie z novějšího serveru spadne do Ostatní', () {
    final fotka = Fotka.fromJson({
      'id': 'x',
      'category': 'podvozek',
      'uploadedAt': '2026-09-15T10:30:00',
    });
    expect(fotka.kategorie, KategorieFotky.ostatni);
  });

  group('fronta nahrávání', () {
    late FakeServiceOrderDataSource zdroj;
    late ProviderContainer kontejner;

    setUp(() {
      zdroj = FakeServiceOrderDataSource([buildOrderDto(id: 'ZK-1')]);
      kontejner = ProviderContainer(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          // V testu bez izolátu - příprava fotky má vlastní testy výše.
          pripravaFotkyProvider.overrideWithValue((data) async => data),
        ],
      );
      addTearDown(kontejner.dispose);
    });

    NahravaniFotek nahravani() =>
        kontejner.read(nahravaniFotekProvider('ZK-1').notifier);
    List<NahravanaFotka> cekajici() =>
        kontejner.read(nahravaniFotekProvider('ZK-1'));

    test('nahrané fotky z fronty zmizí a jsou na serveru', () async {
      await nahravani().pridej(KategorieFotky.exterier, [jpeg(), jpeg()]);

      expect(cekajici(), isEmpty);
      expect(zdroj.fotky['ZK-1'], hasLength(2));
      expect(zdroj.fotky['ZK-1']!.first.kategorie, KategorieFotky.exterier);
      // Bez volby v nastavení se pobočka neposílá.
      expect(zdroj.posledniPobocka, isNull);
    });

    test('fotka jde do pobočky zvolené v nastavení', () async {
      final kontejnerSPobockou = ProviderContainer(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          pripravaFotkyProvider.overrideWithValue((data) async => data),
          nastaveniUlozisteProvider.overrideWithValue(
            PametoveNastaveni(const Nastaveni(slozkaFotek: 'Cestlice')),
          ),
        ],
      );
      addTearDown(kontejnerSPobockou.dispose);

      await kontejnerSPobockou
          .read(nahravaniFotekProvider('ZK-1').notifier)
          .pridej(KategorieFotky.vin, [jpeg()]);

      expect(zdroj.posledniPobocka, 'Cestlice');
    });

    test('fotka, která nešla nahrát, zůstane a jde poslat znovu', () async {
      zdroj.nahravaniSelze = true;
      await nahravani().pridej(KategorieFotky.vin, [jpeg()]);

      expect(cekajici().single.selhala, isTrue);
      expect(cekajici().single.chyba, 'Server neodpovídá.');
      expect(zdroj.fotky['ZK-1'], isNull);

      // Signál je zpátky.
      zdroj.nahravaniSelze = false;
      await nahravani().znovu(cekajici().single.klic);

      expect(cekajici(), isEmpty);
      expect(zdroj.fotky['ZK-1'], hasLength(1));
    });

    test('nepovedenou fotku jde zahodit', () async {
      zdroj.nahravaniSelze = true;
      await nahravani().pridej(KategorieFotky.vin, [jpeg()]);

      nahravani().zahod(cekajici().single.klic);
      expect(cekajici(), isEmpty);
    });

    test('chyba při přípravě jedné fotky nezastaví další ve frontě', () async {
      var poradi = 0;
      final kontejnerSChybou = ProviderContainer(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          pripravaFotkyProvider.overrideWithValue((data) async {
            if (poradi++ == 0) throw StateError('rozbitý obrázek');
            return data;
          }),
        ],
      );
      addTearDown(kontejnerSChybou.dispose);

      await kontejnerSChybou
          .read(nahravaniFotekProvider('ZK-1').notifier)
          .pridej(KategorieFotky.exterier, [jpeg(), jpeg()]);

      // První ohlášená, druhá nahraná - fronta se nezasekla.
      expect(
        kontejnerSChybou.read(nahravaniFotekProvider('ZK-1')).single.selhala,
        isTrue,
      );
      expect(zdroj.fotky['ZK-1'], hasLength(1));
    });

    test('nečitelný obrázek se nenahraje, jen ohlásí', () async {
      final kontejnerSPripravou = ProviderContainer(
        overrides: [
          serviceOrderDataSourceProvider.overrideWithValue(zdroj),
          pripravaFotkyProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(kontejnerSPripravou.dispose);

      await kontejnerSPripravou
          .read(nahravaniFotekProvider('ZK-1').notifier)
          .pridej(KategorieFotky.ostatni, [
            Uint8List.fromList([1, 2, 3]),
          ]);

      expect(
        kontejnerSPripravou.read(nahravaniFotekProvider('ZK-1')).single.chyba,
        'Obrázek se nepodařilo přečíst.',
      );
      expect(zdroj.fotky['ZK-1'], isNull);
    });
  });
}
