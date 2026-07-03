# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

ZapSound is a Flutter app that plays a sound when the device charger is plugged in or unplugged, with a battery-full alert and a premium anti-theft unplug alarm. It has a freemium model gated by a single one-time in-app purchase (`zapsound_premium_lifetime`).

### Layer overview

```
lib/
  main.dart                    # entry point; initializes PurchaseService, charger MethodChannel handler, dark mode pref
  models/sound_model.dart      # SoundModel + ZapSoundLibrary (static sound catalogue) + SoundTarget enum
  services/
    audio_service.dart         # thin wrapper around just_audio AudioPlayer (singleton); play() awaits completion
    battery_service.dart       # BatteryStatus via MethodChannel getBatteryStatus + chargerEvents ValueNotifier
    preferences_service.dart   # thin wrapper around shared_preferences
    purchase_service.dart      # wraps in_app_purchase; listens to purchaseStream in init()
    recording_service.dart     # record pkg wrapper; AAC .m4a to app documents dir; amplitude stream
  screens/
    onboarding_screen.dart     # 3-page PageView shown only on first launch; writes onboarding_done pref
    home_screen.dart           # battery-ring hero (tap = test sound), enable toggle, sound cards, anti-theft toggle
    sound_picker_screen.dart   # category-filtered list; preview/select for plugIn/plugOut/batteryFull targets
    record_sound_screen.dart   # mic recording with live waveform; saves custom_in/custom_out
    premium_screen.dart        # paywall UI; calls PurchaseService.buy/restore
    settings_screen.dart       # dark mode, battery-full alert, anti-theft PIN, reliability, restore, about
  theme/app_theme.dart         # "Electric Glass" design: ZapColors, ZapGradients, ZapTheme, GlassCard, AuraBackground, AppTheme
  widgets/pin_dialog.dart      # showPinSetupDialog — 4-digit PIN entry + confirm
assets/sounds/                 # .wav files referenced by SoundModel.assetPath (incl. siren.wav, alarm-only)
```

### Design system ("Electric Glass")

Dark-first, OLED near-black background (`#050508`). Brand gradient electric violet `#7C5CFF` → cyan `#4CC9FF` (`ZapGradients.brand`); deep-violet `ZapGradients.premium` for hero/badges; gold for premium accents. Typography is Google Fonts **Outfit**. Reusable pieces in `app_theme.dart`: `GlassCard` (blurred translucent card, theme-aware) and `AuraBackground` (soft violet/cyan radial glows behind a `Stack`). The light theme is derived from the dark palette. Micro-animations via `flutter_animate`.

### Android native layer

All native files under `android/app/src/main/kotlin/` in package `com.zapsound.app`, which is also the `applicationId`/namespace (renamed from `com.zapsound.zapsound_fresh` pre-release; the id is permanent once published).

- **`MainActivity.kt`** — starts `ZapForegroundService` in `onCreate` and runs `maybeRunFirstLaunchSetup()` once (chained POST_NOTIFICATIONS → battery-optimization dialog → RECORD_AUDIO, gated by `permission_setup_done` in `zapsound_native` prefs). Registers a dynamic power receiver in `onResume`/`onPause` and forwards events to Flutter over the `com.zapsound.app/charger` `MethodChannel`. Channel methods handled natively: `requestBatteryOptimizationExemption`, `isIgnoringBatteryOptimizations`, `getBatteryStatus` (reads the sticky `ACTION_BATTERY_CHANGED` broadcast; returns level/isCharging/plugType/temperature). `MainActivity.isForeground` tells `ZapReceiver` whether the app is foregrounded; `onResume` re-opens `AlarmActivity` if the siren is active.
- **`ZapReceiver.kt`** — manifest-registered for `ACTION_BOOT_COMPLETED` (restarts the service); receives power events via the service's runtime registration. On `ACTION_POWER_DISCONNECTED`, first checks anti-theft (`flutter.antitheft_armed` + `flutter.antitheft_pin`): if armed it starts `ZapAlarm`, shows the PIN screen (`showAlarmScreen`: direct launch when foregrounded, full-screen-intent notification channel `zapsound_alarm` otherwise) and returns. Otherwise, if foregrounded it returns (Flutter plays via MethodChannel); else it checks `flutter.zapsound_enabled` and plays via `ZapSoundPlayer` using file names from `flutter.plug_in_file` / `flutter.plug_out_file` (defaults `power_up` / `coin`). Custom recordings play from `flutter.custom_in_path` / `flutter.custom_out_path`.
- **`ZapSoundPlayer.kt`** — shared `MediaPlayer` helpers: `play(fileName, customPath)`, `playRes`, `playFile`. Releases players in `setOnCompletionListener`.
- **`ZapAlarm.kt`** — anti-theft siren engine: loops `res/raw/siren.wav` on the ALARM stream at max volume (previous volume restored on stop). Sound is driven here, not in the activity, so it starts instantly from the receiver.
- **`AlarmActivity.kt`** — programmatic full-screen PIN pad shown over the lock screen (`showWhenLocked`/`turnScreenOn`, back disabled). Correct PIN stops `ZapAlarm`, **disarms** (`flutter.antitheft_armed` = false, one-shot), cancels the notification.
- **`ZapForegroundService.kt`** — `START_STICKY` foreground service (channel `zapsound_keepalive`, `IMPORTANCE_MIN`, `foregroundServiceType="dataSync"`). Runtime-registers `ZapReceiver` for power events (implicit broadcasts don't reach manifest receivers on API 26+) and a battery receiver for `ACTION_BATTERY_CHANGED` implementing the **battery-full alert**: when plugged (`EXTRA_PLUGGED != 0`, not `EXTRA_STATUS` — many devices report NOT_CHARGING at 100%) and level ≥ 100, plays `flutter.battery_full_file` (default `ding`) once per charge session (latch resets when unplugged/below 100), gated by `flutter.battery_full_enabled` (default false) and `flutter.zapsound_enabled`.
- **`res/raw/`** — all 31 `.wav` files copied from `assets/sounds/` (30 catalogue sounds + `siren.wav`).
- **Launcher & notification icons** — adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`: gradient `drawable/ic_launcher_background.xml` + white-bolt `mipmap-*/ic_launcher_foreground.png`, monochrome for themed icons) plus legacy `mipmap-*/ic_launcher.png`; all PNGs generated by a stdlib-Python script (bolt polygon, supersampled). Notifications use `drawable/ic_stat_zap.xml` (white bolt vector) — status-bar icons are alpha-masked, so the color launcher icon would render as a blob.
- **Manifest permissions** — `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC`, `RECEIVE_BOOT_COMPLETED`, `RECORD_AUDIO`, `USE_FULL_SCREEN_INTENT` (alarm screen), `com.android.vending.BILLING`. No storage permissions — recordings live in the app documents dir.
- **Release assets** — `docs/privacy_policy.html` (host it, then link from Settings → Privacy policy and the Play data-safety form); `store_assets/play_icon_512.png` (Play listing icon, full-square). Release signing: `android/app/zapsound-release.keystore` + `android/key.properties` (never commit passwords; back the keystore up).
- Test on an emulator: `adb -e shell dumpsys battery set ac 1` (plug) / `set ac 0` (unplug) / `set level 100` (battery full), then `dumpsys battery reset`. Note: the emulator can hit `INSTALL_FAILED_INSUFFICIENT_STORAGE` with debug APKs — uninstall first if `install -r` fails.

### Key design decisions

- **Sound catalogue** lives entirely in `ZapSoundLibrary.all` (`sound_model.dart`). Free sounds `s1`–`s5`; premium `p1`–`p25` plus `custom`. Categories: Classic, Funny, Gaming, Sci-Fi, Retro, Chill, Custom. Adding a sound = add the `SoundModel` entry, drop the `.wav` into `assets/sounds/`, copy it to `res/raw/`. **No Kotlin edit needed**: on selection Dart persists both the id (`plug_in_sound`, UI state) and the file basename (`plug_in_file`, read natively) via `SoundModel.fileName`. Several sounds were synthesized with a stdlib-Python script (44.1 kHz 16-bit mono PCM).
- **`SoundTarget` enum** (`plugIn` / `plugOut` / `batteryFull`) parameterizes `SoundPickerScreen`; the batteryFull target hides the custom-recording row and persists via `setBatteryFullSound(id, file)`.
- **Anti-theft (premium)** — armed via Home toggle (PIN set on first arm through `showPinSetupDialog`; changeable in Settings → Alerts). Prefs: `antitheft_armed`, `antitheft_pin`. The Dart MethodChannel handler skips the unplug sound while armed; the native receiver handles the siren + PIN screen. Disarms itself after each triggered alarm.
- **Premium gate** is a boolean in SharedPreferences (`is_premium`). `PurchaseService.init()` must be called before `runApp`. `restoreAndCheck()` polls `isPremium` (10 × 400 ms) after restore instead of a fixed wait. The Home banner and paywall both show the live store price via `getProduct()` (fallback `$2.99`).
- **Battery status on Home** — `BatteryService.getStatus()` (null on platforms without the channel, e.g. iOS). The hero ring (`_BatteryRingPainter`) shows level with a brand-gradient sweep; refreshed by a 15 s timer plus `BatteryService.chargerEvents`, a `ValueNotifier` bumped by the `main.dart` MethodChannel handler on plug/unplug. "Plugged in" is derived from `plugType` (`isPluggedIn`), not `isCharging`.
- **Previews await real playback**: just_audio's `play()` future completes when the sound ends or `AudioService.stop()` is called — no fixed delays. Tapping an active preview stops it.
- **Custom sound** (id `custom`) stores a file path in prefs (`custom_in_path` / `custom_out_path`); can be re-recorded or removed in the picker (removal deletes the file and reverts selection to `s1`/`s2` + file mirror).
- **Master enable toggle** — `zapsound_enabled` pref (default `true`); checked in the `main.dart` handler, `ZapReceiver`, and the battery-full receiver. The Home ring "tap to test" bypasses it (hit area is clipped to the ring's circle via an `onTapUp` distance check — a plain `onTap` would fire on the corners of the 224×224 box).
- **Volume** — `volume_pct` pref (int 0–100, default 100). Applied in `AudioService` (`setVolume` before play) and natively in `ZapSoundPlayer` (reads `flutter.volume_pct` as Long — shared_preferences stores Dart ints as Long). Settings slider previews the plug-in sound on release.
- **Quiet hours** — `quiet_hours_enabled` / `quiet_start_min` / `quiet_end_min` prefs (defaults off, 22:00→07:00; window may wrap midnight). Checked in the `main.dart` handler (`PrefsService.isQuietNow()`) and natively (`ZapSoundPlayer.isQuietNow()`, used by `ZapReceiver` + battery-full receiver). Anti-theft siren intentionally ignores it.
- **Settings sections** — Sound (volume, quiet hours) → Alerts (battery full, anti-theft PIN) → Appearance → Background & Reliability → Purchase (hidden when premium) → About. `_Tile` takes a nullable `onTap`; `null` hides the chevron (Version row).
- **Theme toggling** — `_ZapSoundAppState` owns a `ValueNotifier<bool>`; `SettingsScreen` persists via `PrefsService.setDarkMode` and live-updates via `ZapSoundApp.of(context)?.setDark`.
- **Onboarding** — `main()` reads `isOnboarded` and sets `home` accordingly; reset by clearing the `onboarding_done` pref.
- **HomeScreen uses `resizeToAvoidBottomInset: false`** — the fixed hero layout must not squash when a dialog keyboard opens.
