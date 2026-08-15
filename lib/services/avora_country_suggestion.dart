import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AvoraCountrySuggestion {
  static const _channel = MethodChannel('com.officialavora.app/device');

  static Future<String?> resolve() async {
    try {
      final networkCode = await _channel.invokeMethod<String>('countryCode');
      if (networkCode != null && networkCode.trim().length == 2) {
        return networkCode.trim().toUpperCase();
      }
    } on PlatformException {
      // Device region is a safe fallback when network country is unavailable.
    } on MissingPluginException {
      // Widget tests and unsupported platforms use the fallback below.
    }
    return WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
  }
}
