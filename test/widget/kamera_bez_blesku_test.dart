import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:renoworkshop/src/features/orders/presentation/screens/skener_screen.dart';
import 'package:renoworkshop/src/features/prijem/presentation/screens/seriove_foceni_screen.dart';

/// Kamera jako na tabletu bez blesku a s pevným ostřením: spustí se, ale
/// blesk ani ostření nastavit nejde. Na takovém tabletu focení u příjmu
/// padalo s „setFlashModeFailed".
class _KameraBezBlesku extends CameraPlatform with MockPlatformInterfaceMixin {
  final _inicializovano = StreamController<CameraInitializedEvent>.broadcast();

  /// Start kamery selže - třeba ji drží jiná aplikace.
  bool startSelze = false;
  int zavreno = 0;

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
  Future<void> setFlashMode(int cameraId, FlashMode mode) async =>
      throw PlatformException(
        code: 'setFlashModeFailed',
        message: 'Bez blesku',
      );

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
  tearDown(() => CameraPlatform.instance = puvodni);

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
}
