import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _plugIn    = 'plug_in_sound';
  static const _plugOut   = 'plug_out_sound';
  static const _premium   = 'is_premium';
  static const _darkMode  = 'is_dark_mode';
  static const _onboarded = 'onboarding_done';
  static const _customIn  = 'custom_in_path';
  static const _customOut = 'custom_out_path';
  static const _enabled   = 'zapsound_enabled';

  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static Future<String>  getPlugIn()     async => (await _p).getString(_plugIn)  ?? 's1';
  static Future<String>  getPlugOut()    async => (await _p).getString(_plugOut) ?? 's2';
  static Future<bool>    isPremium()     async => (await _p).getBool(_premium)   ?? false;
  static Future<bool>    isDarkMode()    async => (await _p).getBool(_darkMode)  ?? true;
  static Future<bool>    isOnboarded()   async => (await _p).getBool(_onboarded) ?? false;
  static Future<String?> getCustomIn()   async => (await _p).getString(_customIn);
  static Future<String?> getCustomOut()  async => (await _p).getString(_customOut);
  static Future<bool>    isEnabled()     async => (await _p).getBool(_enabled)   ?? true;

  static Future<void> setPlugIn(String v)     async => (await _p).setString(_plugIn, v);
  static Future<void> setPlugOut(String v)    async => (await _p).setString(_plugOut, v);
  static Future<void> setPremium(bool v)      async => (await _p).setBool(_premium, v);
  static Future<void> setDarkMode(bool v)     async => (await _p).setBool(_darkMode, v);
  static Future<void> setOnboarded(bool v)    async => (await _p).setBool(_onboarded, v);
  static Future<void> setCustomIn(String v)   async => (await _p).setString(_customIn, v);
  static Future<void> setCustomOut(String v)  async => (await _p).setString(_customOut, v);
  static Future<void> setEnabled(bool v)      async => (await _p).setBool(_enabled, v);
}
