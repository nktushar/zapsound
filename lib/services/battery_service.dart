import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BatteryStatus {
  final int level; // 0–100, -1 if unknown
  final bool isCharging;
  final String plugType; // 'AC' / 'USB' / 'Wireless' / ''
  final double temperature; // °C, -1 if unknown

  const BatteryStatus({
    required this.level,
    required this.isCharging,
    required this.plugType,
    required this.temperature,
  });

  /// True whenever a power source is attached, even if the OS reports
  /// NOT_CHARGING (e.g. battery already full).
  bool get isPluggedIn => plugType.isNotEmpty;
}

class BatteryService {
  static const _channel = MethodChannel('com.zapsound.app/charger');

  /// Bumped by main.dart's charger event handler so screens can refresh
  /// battery info the moment the charger is plugged/unplugged.
  static final chargerEvents = ValueNotifier<int>(0);

  /// Android 14+ may deny full-screen intents, which keeps the anti-theft PIN
  /// screen from appearing over the lock screen. True when allowed or unknown.
  static Future<bool> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openFullScreenIntentSettings() async {
    try {
      await _channel.invokeMethod('openFullScreenIntentSettings');
    } catch (_) {}
  }

  static Future<BatteryStatus?> getStatus() async {
    try {
      final res = await _channel.invokeMethod<Map<Object?, Object?>>('getBatteryStatus');
      if (res == null) return null;
      return BatteryStatus(
        level: (res['level'] as num?)?.toInt() ?? -1,
        isCharging: res['isCharging'] as bool? ?? false,
        plugType: res['plugType'] as String? ?? '',
        temperature: (res['temperature'] as num?)?.toDouble() ?? -1,
      );
    } catch (_) {
      // Channel not implemented on this platform (e.g. unit tests).
      return null;
    }
  }
}
