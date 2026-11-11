import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug-only premium override for testing Pro features without a purchase:
/// `flutter run --dart-define=ZAP_FORCE_PREMIUM=true`. Always false in
/// profile/release builds (kDebugMode), so it can never ship unlocked.
const bool kForcePremium =
    kDebugMode && bool.fromEnvironment('ZAP_FORCE_PREMIUM');

class PrefsService {
  static const _plugIn    = 'plug_in_sound';
  static const _plugOut   = 'plug_out_sound';
  static const _premium   = 'is_premium';
  static const _darkMode  = 'is_dark_mode'; // legacy bool, read once for migration
  static const _themeMode = 'theme_mode';    // 'system' | 'light' | 'dark'
  static const _onboarded = 'onboarding_done';
  static const _customIn  = 'custom_in_path';
  static const _customOut = 'custom_out_path';
  static const _enabled   = 'zapsound_enabled';
  // File-name mirrors read by the native layer (ZapReceiver / foreground service).
  static const _plugInFile      = 'plug_in_file';
  static const _plugOutFile     = 'plug_out_file';
  static const _battFullEnabled = 'battery_full_enabled';
  static const _battFullSound   = 'battery_full_sound';
  static const _battFullFile    = 'battery_full_file';
  static const _antitheftArmed  = 'antitheft_armed';
  static const _antitheftPin    = 'antitheft_pin';
  // Volume + quiet hours are also read natively (ZapSoundPlayer) as
  // flutter.volume_pct / flutter.quiet_* — ints stored as Long on Android.
  static const _volume       = 'volume_pct';
  static const _quietEnabled = 'quiet_hours_enabled';
  static const _quietStart   = 'quiet_start_min';
  static const _quietEnd     = 'quiet_end_min';

  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static Future<String>  getPlugIn()     async => (await _p).getString(_plugIn)  ?? 's1';
  static Future<String>  getPlugOut()    async => (await _p).getString(_plugOut) ?? 's2';
  static Future<bool>    isPremium()     async => kForcePremium || ((await _p).getBool(_premium) ?? false);
  static Future<bool>    isOnboarded()   async => (await _p).getBool(_onboarded) ?? false;
  static Future<String?> getCustomIn()   async => (await _p).getString(_customIn);
  static Future<String?> getCustomOut()  async => (await _p).getString(_customOut);
  static Future<bool>    isEnabled()     async => (await _p).getBool(_enabled)   ?? true;
  static Future<bool>    isBatteryFullEnabled() async => (await _p).getBool(_battFullEnabled) ?? false;
  static Future<String>  getBatteryFullSound()  async => (await _p).getString(_battFullSound) ?? 's4';
  static Future<bool>    isAntitheftArmed()     async => (await _p).getBool(_antitheftArmed) ?? false;
  static Future<String?> getAntitheftPin()      async => (await _p).getString(_antitheftPin);

  static Future<void> setPlugIn(String v)     async => (await _p).setString(_plugIn, v);
  static Future<void> setPlugOut(String v)    async => (await _p).setString(_plugOut, v);
  static Future<void> setPremium(bool v)      async => (await _p).setBool(_premium, v);
  static Future<void> setOnboarded(bool v)    async => (await _p).setBool(_onboarded, v);
  static Future<void> setCustomIn(String v)   async => (await _p).setString(_customIn, v);
  static Future<void> setCustomOut(String v)  async => (await _p).setString(_customOut, v);
  static Future<void> setEnabled(bool v)      async => (await _p).setBool(_enabled, v);
  static Future<void> clearCustomIn()         async => (await _p).remove(_customIn);
  static Future<void> clearCustomOut()        async => (await _p).remove(_customOut);
  static Future<void> setPlugInFile(String v)       async => (await _p).setString(_plugInFile, v);
  static Future<void> setPlugOutFile(String v)      async => (await _p).setString(_plugOutFile, v);
  static Future<void> setBatteryFullEnabled(bool v) async => (await _p).setBool(_battFullEnabled, v);
  static Future<void> setBatteryFullSound(String id, String file) async {
    final p = await _p;
    await p.setString(_battFullSound, id);
    await p.setString(_battFullFile, file);
  }
  static Future<void> setAntitheftArmed(bool v)   async => (await _p).setBool(_antitheftArmed, v);
  static Future<void> setAntitheftPin(String v)   async => (await _p).setString(_antitheftPin, v);

  /// 'system' | 'light' | 'dark'. Falls back to the legacy dark-mode bool,
  /// then to following the system theme.
  static Future<String> getThemeMode() async {
    final p = await _p;
    final v = p.getString(_themeMode);
    if (v != null) return v;
    final legacy = p.getBool(_darkMode);
    if (legacy == null) return 'system';
    return legacy ? 'dark' : 'light';
  }
  static Future<void> setThemeMode(String v) async => (await _p).setString(_themeMode, v);

  static Future<int>  getVolume()      async => (await _p).getInt(_volume) ?? 100;
  static Future<void> setVolume(int v) async => (await _p).setInt(_volume, v.clamp(0, 100));

  static Future<bool> isQuietHoursEnabled()        async => (await _p).getBool(_quietEnabled) ?? false;
  static Future<void> setQuietHoursEnabled(bool v) async => (await _p).setBool(_quietEnabled, v);
  static Future<int>  getQuietStart()      async => (await _p).getInt(_quietStart) ?? 22 * 60;
  static Future<int>  getQuietEnd()        async => (await _p).getInt(_quietEnd)   ?? 7 * 60;
  static Future<void> setQuietStart(int m) async => (await _p).setInt(_quietStart, m);
  static Future<void> setQuietEnd(int m)   async => (await _p).setInt(_quietEnd, m);

  /// True when quiet hours are enabled and the current time is inside the
  /// window. The window may wrap past midnight (e.g. 22:00 → 07:00).
  /// Mirrored natively by ZapSoundPlayer.isQuietNow().
  static Future<bool> isQuietNow() async {
    if (!await isQuietHoursEnabled()) return false;
    final start = await getQuietStart();
    final end = await getQuietEnd();
    if (start == end) return false;
    final now = DateTime.now();
    final min = now.hour * 60 + now.minute;
    return start < end ? (min >= start && min < end) : (min >= start || min < end);
  }
}
