import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/fotodokumentace/presentation/screens/seriove_foceni_screen.dart';

/// Kamera jako na tabletu bez blesku a s pevným ostřením: spustí se, ale
/// blesk ani ostření nastavit nejde. Na takovém tabletu focení u příjmu
/// padalo s „setFlashModeFailed".
class _KameraBezBlesku extends CameraPlatform with MockPlatformInterfaceMixin {
  final _inicializovano = StreamController<CameraInitializedEvent>.broadcast();

  /// Start kamery selže - třeba ji drží jiná aplikace.
  bool startSelze = false;
  int zavreno = 0;

  /// Telefon s bleskem: setFlashMode projde a pamatuje si režim.
  bool maBlesk = false;
  FlashMode? blesk;

  /// Soubory, které „fotoaparát" vyrobil - test je uklidí.
  final List<File> snimky = [];

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'zadni',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => 1;

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _inicializovano.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _chyby.stream;

  /// Otevřený a tichý - kamera na první chybu čeká, prázdný stream by
  /// skončil výjimkou.
  final _chyby = StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (startSelze) {
      throw PlatformException(code: 'CameraAccess', message: 'Obsazeno');
    }
    _inicializovano.add(
      const CameraInitializedEvent(
        1,
        1280,
        720,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    if (!maBlesk) {
      throw PlatformException(
        code: 'setFlashModeFailed',
        message: 'Bez blesku',
      );
    }
    blesk = mode;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    final soubor = File(
      '${Directory.systemTemp.path}/renoworkshop-test-${snimky.length}.jpg',
    )..writeAsBytesSync(img.encodeJpg(img.Image(width: 8, height: 8)));
    snimky.add(soubor);
    return XFile(soubor.path);
  }

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async =>
      throw PlatformException(code: 'setFocusModeFailed', message: 'Pevné');

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);

  @override
  Future<void> dispose(int cameraId) async => zavreno++;
}

void main() {
  late CameraPlatform puvodni;
  late _KameraBezBlesku kamera;

  setUp(() {
    puvodni = CameraPlatform.instance;
    kamera = _KameraBezBlesku();
    CameraPlatform.instance = kamera;
  });
  tearDown(() {
    CameraPlatform.instance = puvodni;
    for (final soubor in kamera.snimky) {
      try {
        if (soubor.existsSync()) soubor.deleteSync();
      } on FileSystemException {
        // Windows drží soubor otevřený déle - úklid dočasného souboru
        // není důvod shodit test.
      }
    }
  });

  Future<void> otevri(WidgetTester tester, Widget obrazovka) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: obrazovka)));
    // Start kamery je řada asynchronních kroků - pár snímků, ne
    // pumpAndSettle (náhled se překresluje pořád).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('focení u příjmu se spustí i na zařízení bez blesku', (
    tester,
  ) async {
    await otevri(
      tester,
      SerioveFoceniScreen(nadpis: 'Exteriér', onFotka: (_) {}),
    );

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.textContaining('nepodařilo spustit'), findsNothing);
  });

  testWidgets('skener se spustí i na zařízení s pevným ostřením', (
    tester,
  ) async {
    await otevri(tester, SkenerScreen(onNalezeno: (_) {}, onBack: () {}));

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.textContaining('nepodařilo spustit'), findsNothing);
  });

  testWidgets('kamera, která se nespustí, se zavře a technik vidí proč', (
    tester,
  ) async {
    kamera.startSelze = true;
    await otevri(
      tester,
      SerioveFoceniScreen(nadpis: 'Exteriér', onFotka: (_) {}),
    );

    expect(
      find.text('Fotoaparát se nepodařilo spustit (CameraAccess).'),
      findsOneWidget,
    );
    expect(kamera.zavreno, 1);
  });

  group('sériové focení', () {
    /// Focení otevřené přes jinou obrazovku - jde z něj tedy odejít zpět.
    Future<void> otevriFoceni(
      WidgetTester tester, {
      void Function(Uint8List fotka)? onFotka,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SerioveFoceniScreen(
                          nadpis: 'Zjištěná poškození',
                          onFotka: onFotka ?? (_) {},
                        ),
                      ),
                    ),
                    child: const Text('Fotit'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Fotit'));
      // Přechod na obrazovku a start kamery.
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(CameraPreview), findsOneWidget);
    }

    testWidgets('z focení jde zpět šipkou', (tester) async {
      await otevriFoceni(tester);
      expect(find.byType(SerioveFoceniScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('foceni-zpet')));
      await tester.pumpAndSettle();

      expect(find.byType(SerioveFoceniScreen), findsNothing);
    });

    testWidgets('blesk se přepíná vypnuto, automaticky, zapnuto', (
      tester,
    ) async {
      kamera.maBlesk = true;
      await otevriFoceni(tester);

      final tlacitko = find.byKey(const Key('foceni-blesk'));
      expect(kamera.blesk, FlashMode.off);

      await tester.tap(tlacitko);
      await tester.pump();
      expect(kamera.blesk, FlashMode.auto);
      expect(find.byIcon(Icons.flash_auto_rounded), findsOneWidget);

      await tester.tap(tlacitko);
      await tester.pump();
      expect(kamera.blesk, FlashMode.always);

      await tester.tap(tlacitko);
      await tester.pump();
      expect(kamera.blesk, FlashMode.off);
    });

    testWidgets('na zařízení bez blesku tlačítko není', (tester) async {
      await otevriFoceni(tester);
      expect(find.byKey(const Key('foceni-blesk')), findsNothing);
    });

    testWidgets('po vyfocení je v rohu náhled s počtem', (tester) async {
      final vyfocene = <Uint8List>[];
      await otevriFoceni(tester, onFotka: vyfocene.add);
      expect(find.byKey(const Key('foceni-nahled')), findsNothing);

      await tester.tap(find.byKey(const Key('foceni-spoust')));
      // Fotka se čte ze souboru - skutečné I/O, které v testu běží jen
      // uvnitř runAsync.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(vyfocene, hasLength(1));
      expect(find.byKey(const Key('foceni-nahled')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Hotovo (1)'), findsOneWidget);
    });
  });
}
