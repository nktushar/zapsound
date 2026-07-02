# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install dependencies
flutter run              # run on connected device/emulator
flutter run -d android   # target Android specifically
flutter run -d ios       # target iOS specifically
flutter analyze          # lint (uses analysis_options.yaml with flutter_lints)
flutter test             # run all tests
flutter test test/widget_test.dart  # run a single test file
flutter build apk        # build Android release
flutter build ios        # build iOS release
```

## Architecture

ZapSound is a Flutter app that plays a sound when the device charger is plugged in or unplugged. It has a freemium model gated by a single one-time in-app purchase (`zapsound_premium_lifetime`).

### Layer overview

```
lib/
  main.dart                    # entry point; initializes PurchaseService and reads dark mode pref
  models/sound_model.dart      # SoundModel + ZapSoundLibrary (static sound catalogue)
  services/
    audio_service.dart         # thin wrapper around just_audio AudioPlayer (singleton)
    preferences_service.dart   # thin wrapper around shared_preferences
    purchase_service.dart      # wraps in_app_purchase; listens to purchaseStream in init()
  screens/
    onboarding_screen.dart     # 3-page PageView shown only on first launch; writes onboarding_done pref
    home_screen.dart           # main screen with zap button and sound selector cards
    sound_picker_screen.dart   # category-filtered list; preview and select sounds
    premium_screen.dart        # paywall UI; calls PurchaseService.buy/restore
    settings_screen.dart       # dark mode toggle, restore purchase, about links
  theme/app_theme.dart         # ZapColors, ZapTheme (spacing/radius/text constants), AppTheme
assets/sounds/                 # .wav files referenced by SoundModel.assetPath
```

### Android native layer

- **`MainActivity.kt`** — on `onCreate`, starts `ZapForegroundService` (so the process survives after the app is swiped away) and runs `maybeRunFirstLaunchSetup()` once, gated by `permission_setup_done` in `zapsound_native` SharedPreferences (flag written before anything shows, so a crash doesn't re-trigger it). The setup is a chained sequence: (1) request `POST_NOTIFICATIONS` on Android 13+ via `ActivityCompat.requestPermissions`, (2) on the permission callback (or immediately on <13), show the battery-optimization `AlertDialog` and fire `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` if OK is tapped (a targeted system dialog, not the generic settings list), (3) either dialog button leads to requesting `RECORD_AUDIO`. It also registers a dynamic `BroadcastReceiver` for `ACTION_POWER_CONNECTED`/`ACTION_POWER_DISCONNECTED` in `onResume`/`onPause` (foreground-only backup) and forwards those events to Flutter over the `com.zapsound.app/charger` `MethodChannel` (`onChargerConnected`/`onChargerDisconnected`). `MainActivity.isForeground` (companion object flag, set in `onResume`/`onPause`) tells `ZapReceiver` whether the app is foregrounded.
- **`ZapReceiver.kt`** — manifest-registered `BroadcastReceiver` (declared with its fully-qualified name `com.zapsound.app.ZapReceiver` since its package differs from the app namespace `com.zapsound.zapsound_fresh`) that catches `ACTION_POWER_CONNECTED` / `ACTION_POWER_DISCONNECTED` / `ACTION_BOOT_COMPLETED`. On boot it starts `ZapForegroundService` and returns. For power events, if `MainActivity.isForeground` is true it returns early (Flutter handles playback via the MethodChannel + `AudioService` instead, to avoid double-playing). Otherwise it reads sound IDs from `FlutterSharedPreferences` (keys `flutter.plug_in_sound` / `flutter.plug_out_sound`), maps them to `res/raw/` filenames via `soundIdToResName()`, and plays with `MediaPlayer`. Custom recordings use `playFile()` with the path stored under `flutter.custom_in_path` / `flutter.custom_out_path`. `MediaPlayer` is released in `setOnCompletionListener` to avoid leaks.
- **`ZapForegroundService.kt`** — minimal `Service` started from `MainActivity.onCreate` and from `ZapReceiver` on `ACTION_BOOT_COMPLETED`. Shows a low-priority ("ZapSound is active") ongoing notification via `startForeground` (channel `zapsound_keepalive`, `IMPORTANCE_MIN`) and returns `START_STICKY` so the OS keeps the process around to deliver charger broadcasts to `ZapReceiver` even when the app is closed. Declared in the manifest with `android:foregroundServiceType="dataSync"` (required on Android 14+).
- **`res/raw/`** — all 15 `.wav` files copied from `assets/sounds/`. These are the same files Flutter uses; `soundIdToResName()` in `ZapReceiver` must stay in sync with `ZapSoundLibrary` in `sound_model.dart` whenever sounds are added.
- **Manifest permissions** — `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (battery exemption intent), `POST_NOTIFICATIONS` (Android 13+, required for the foreground service notification), `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC` (for `ZapForegroundService`), `RECEIVE_BOOT_COMPLETED` (restart the service after reboot), `RECORD_AUDIO` (custom sound recording).
- **Charger detection while foregrounded** — `lib/main.dart` registers a handler on the `com.zapsound.app/charger` `MethodChannel` before `runApp`, calling `AudioService.onPlugIn()`/`onPlugOut()` directly when notified. This is the "more reliable" foreground path; `ZapReceiver` remains the path used when the app is backgrounded or fully closed.
- Test charger detection on an emulator with `adb -e shell dumpsys battery set ac 1` (plug) / `adb -e shell dumpsys battery set ac 0` (unplug), then `adb -e shell dumpsys battery reset` to restore normal behavior.

### Key design decisions

- **Sound catalogue** lives entirely in `ZapSoundLibrary.all` (`sound_model.dart`). Free sounds have IDs `s1`–`s5`; premium sounds have IDs `p1`–`p10` plus `custom`. Adding a new sound means adding a `SoundModel` entry here and dropping the `.wav` into `assets/sounds/`.
- **Premium gate** is a boolean in SharedPreferences (`is_premium`). `PurchaseService.init()` must be called before `runApp` to attach the purchase stream listener that sets this flag. All UI checks call `PrefsService.isPremium()` directly — there is no global state or provider.
- **Theme toggling** — `_ZapSoundAppState` owns a `ValueNotifier<bool> _themeNotifier` initialised from the prefs-read `isDark` passed into `ZapSoundApp`. `ValueListenableBuilder` wraps `MaterialApp` so only it rebuilds on change. `SettingsScreen` calls both `PrefsService.setDarkMode(v)` (persist) and `ZapSoundApp.of(context)?.setDark(v)` (live update) in the toggle's `onChanged`.
- **Onboarding** — `main()` reads `isOnboarded` from prefs and passes it to `ZapSoundApp`, which sets `home` to `OnboardingScreen` or `HomeScreen`. `OnboardingScreen` calls `PrefsService.setOnboarded(true)` then `pushReplacement` to `HomeScreen` with a fade transition. To reset onboarding during development, clear app data or delete the `onboarding_done` SharedPreferences key.
- **Custom sound** (id `custom`) stores a file path in prefs (`custom_in_path` / `custom_out_path`). `AudioService.onPlugIn/onPlugOut` checks for this id and uses `setFilePath` instead of `setAsset`.
- **`AudioService`** uses a single shared `AudioPlayer` instance — calling `playAsset` or `playFile` stops any currently playing audio first.
