import 'package:flutter/material.dart';

/// Adaptivní chrome: iOS vs. Android.
///
/// Rozhoduje se podle `Theme.of(context).platform`, ne podle `dart:io` -
/// díky tomu jde platformu přepnout v testech i v debug preview.
extension PlatformInfo on BuildContext {
  bool get isIOS {
    final platform = Theme.of(this).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  bool get isAndroidStyle => !isIOS;
}
