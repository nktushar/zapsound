# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install dependencies
flutter run              # run on connected device/emulator
flutter run -d android   # target Android (the only platform)
flutter analyze          # lint (uses analysis_options.yaml with flutter_lints)
flutter test             # run all tests
flutter test test/widget_test.dart  # run a single test file
flutter build apk        # build Android release
```

## Architecture

ZapSound is an **Android-only** Flutter app (iOS/desktop/web platform folders removed — iOS cannot detect the charger in the background) that plays a sound when the device charger is plugged in or unplugged, with a battery-full alert and a premium anti-theft unplug alarm. It has a freemium model gated by a single one-time in-app purchase (`zapsound_premium_lifetime`).

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
    home_screen.dart           # tick-dial battery hero (tap = test sound); "Charger sounds" header w/ master switch; plug-in/unplug moment tiles; "More alerts" group (battery full split-switch → picker, unplug alarm); ink Pro card
    sound_picker_screen.dart   # SliverAppBar.large + pinned filter chips + SoundPad grid; tap = preview AND select (saved instantly, no close); locked pads preview + unlock bar
    record_sound_screen.dart   # mic recording with live waveform (moment hue), 10 s cap; saves custom_in/custom_out (+ file mirror)
    premium_screen.dart        # paywall: tappable sound chips (hear before buying), hue-coded feature group, sticky ink CTA
    settings_screen.dart       # Pro status, sound (volume, quiet hours), unplug alarm PIN, theme (System/Light/Dark), background (OEM help sheet), purchase, about
  theme/app_theme.dart         # "Moments" design: ZapHue/ZapTokens (`context.zap`), zapDisplay(), ZapTheme, Pressable, ZapGroup/ZapItem/SplitSwitch, ZapSectionLabel, ProTag, ZapPrimaryButton, ZapSegmented, page transition, AppTheme
  widgets/pin_dialog.dart      # showPinSetupDialog — single dialog, 4 PIN boxes, enter + confirm steps, inline mismatch error
  widgets/sound_widgets.dart   # SoundPad, PlayButton, EqualizerBars, categoryIcon(), hueForTarget(), hueForCategory()
assets/sounds/                 # .wav (synthesized originals, incl. alarm-only siren.wav) + .mp3 (imported fun pack) referenced by SoundModel.assetPath
```

### Design system ("Moments")

The interface is **monochrome** — ink (`#131316` light / `#F2F2F5` dark) is the primary color for text, filled buttons (stadium shape), switches, chips and selection. **Color only carries meaning**: each sound moment owns a tonal `ZapHue` (container / onContainer / strong) that follows it everywhere — `charge` emerald = plug in & charging (dial ticks, tile, picker selection, record waveform, test ripple), `release` coral = unplug, `full` blue = battery full, `guard` violet = unplug alarm (armed row tints violet). `danger` red = low battery / recording / alarm screen. Backgrounds `#F1F1F3` / `#0D0D0F`, surfaces white / `#1A1A1D`. No borders, shadows or gradients.

Surfaces are tiered by role, not one card style: dial floats free; moment tiles (r28) and Pro card (inverted ink, r28) are hero blocks; secondary options use `ZapGroup` — Android-16-style segmented lists (each `ZapItem` on its own surface, outer r24 / inner r6, 2 px gaps); picker pads r20. Rows use plain muted icons, or a hue circle when the row *is* a moment. Two-target rows (body opens detail, switch toggles) use `SplitSwitch`. Type: **Bricolage Grotesque** via `zapDisplay()` for numbers, titles, sound names (also wired into `headline*`/`titleLarge`, so `SliverAppBar.large` titles get it) + **Manrope** body; numbers use `ZapTheme.tabular`. Motion: one custom shared-axis page transition for all routes, `Pressable` press-scale on tiles/pads, state-change animations only. Theme pref `theme_mode` ('system' | 'light' | 'dark', default system; falls back to legacy `is_dark_mode` bool). Native `AlarmActivity` + first-launch dialog (`Theme_DeviceDefault_Dialog_Alert`) match the dark palette.

### Android native layer

All native files under `android/app/src/main/kotlin/` in package `com.zapsound.app`, which is also the `applicationId`/namespace (renamed from `com.zapsound.zapsound_fresh` pre-release; the id is permanent once published).

- **`MainActivity.kt`** — starts `ZapForegroundService` in `onCreate` and runs `maybeRunFirstLaunchSetup()` once (chained POST_NOTIFICATIONS → battery-optimization dialog → RECORD_AUDIO, gated by `permission_setup_done` in `zapsound_native` prefs). Registers a dynamic power receiver in `onResume`/`onPause` and forwards events to Flutter over the `com.zapsound.app/charger` `MethodChannel`. Channel methods handled natively: `requestBatteryOptimizationExemption`, `isIgnoringBatteryOptimizations`, `canUseFullScreenIntent` / `openFullScreenIntentSettings` (Android 14+ FSI permission; Home prompts after arming anti-theft if denied), `getBatteryStatus` (reads the sticky `ACTION_BATTERY_CHANGED` broadcast; returns level/isCharging/plugType/temperature). `MainActivity.isForeground` tells `ZapReceiver` whether the app is foregrounded; `onResume` re-opens `AlarmActivity` if the siren is active.
- **`ZapReceiver.kt`** — manifest-registered for `ACTION_BOOT_COMPLETED` (restarts the service); receives power events via the service's runtime registration. On `ACTION_POWER_DISCONNECTED`, first checks anti-theft (`flutter.antitheft_armed` + `flutter.antitheft_pin`): if armed it starts `ZapAlarm`, shows the PIN screen (`showAlarmScreen`: direct launch when foregrounded, full-screen-intent notification channel `zapsound_alarm` otherwise; the notification's content intent also opens the PIN screen, the fallback when FSI is denied) and returns. Otherwise, if foregrounded it returns (Flutter plays via MethodChannel); else it checks `flutter.zapsound_enabled` and plays via `ZapSoundPlayer` using file names from `flutter.plug_in_file` / `flutter.plug_out_file` (defaults `power_up` / `coin`). Custom recordings play from `flutter.custom_in_path` / `flutter.custom_out_path`.
- **`ZapSoundPlayer.kt`** — shared `MediaPlayer` helpers: `play(fileName, customPath)`, `playRes`, `playFile`. Keeps each player in a strongly-referenced `active` set until completion/error, then releases it (a local-only `MediaPlayer` gets GC'd mid-sound: "finalized without being released").
- **`ZapAlarm.kt`** — anti-theft siren engine: loops `res/raw/siren.wav` on the ALARM stream at max volume (previous volume restored on stop). Sound is driven here, not in the activity, so it starts instantly from the receiver.
- **`AlarmActivity.kt`** — programmatic full-screen PIN pad shown over the lock screen (`showWhenLocked`/`turnScreenOn`, back disabled). Correct PIN stops `ZapAlarm`, **disarms** (`flutter.antitheft_armed` = false, one-shot), cancels the notification.
- **`ZapForegroundService.kt`** — `START_STICKY` foreground service (channel `zapsound_keepalive`, `IMPORTANCE_MIN`, `foregroundServiceType="specialUse"` with a `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` justification — **not** `dataSync`, which Android 15+ caps at 6 h/24 h and blocks from `BOOT_COMPLETED`; needs a Play Console FGS declaration). Runtime-registers `ZapReceiver` for power events (implicit broadcasts don't reach manifest receivers on API 26+) and a battery receiver for `ACTION_BATTERY_CHANGED` implementing the **battery-full alert**: when plugged (`EXTRA_PLUGGED != 0`, not `EXTRA_STATUS` — many devices report NOT_CHARGING at 100%) and level ≥ 100, plays `flutter.battery_full_file` (default `ding`) once per charge session (latch resets when unplugged/below 100), gated by `flutter.battery_full_enabled` (default false) and `flutter.zapsound_enabled`.
- **`res/raw/`** — every catalogue sound copied from `assets/sounds/` (30 `.wav` + 113 `.mp3`) plus `siren.wav`. Raw resource names must be unique by basename regardless of extension (`[a-z][a-z0-9_]*`); a test enforces asset + raw twin exist.
- **Launcher & notification icons** — adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`: solid ink `#131316` `drawable/ic_launcher_background.xml` + white-bolt vector `drawable/ic_launcher_foreground.xml` (same path as `ic_stat_zap`, scaled into the 66dp safe zone; also the monochrome layer for themed icons)) plus legacy `mipmap-*/ic_launcher.png` (ink rounded square) and `store_assets/play_icon_512.png`; the PNGs are rasterized from the bolt path by a stdlib-Python script (supersampled, no PIL). Notifications use `drawable/ic_stat_zap.xml` (white bolt vector) — status-bar icons are alpha-masked, so the color launcher icon would render as a blob.
- **Manifest permissions** — `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE`, `RECEIVE_BOOT_COMPLETED`, `RECORD_AUDIO`, `USE_FULL_SCREEN_INTENT` (alarm screen), `com.android.vending.BILLING`. No storage permissions — recordings live in the app documents dir.
- **Release assets** — `docs/privacy_policy.html` (host it, then link from Settings → Privacy policy and the Play data-safety form); `store_assets/play_icon_512.png` (Play listing icon, full-square). `store_assets/play_console_declarations.md` — paste-ready Play Console App-content answers (FGS specialUse, full-screen intent, battery-optimization justification, IARC, target audience 13+, data safety); keep in sync when features change. Release signing: `android/app/zapsound-release.keystore` + `android/key.properties` (never commit passwords; back the keystore up).
- Test on an emulator: `adb -e shell dumpsys battery set ac 1` (plug) / `set ac 0` (unplug) / `set level 100` (battery full), then `dumpsys battery reset`. Note: the emulator can hit `INSTALL_FAILED_INSUFFICIENT_STORAGE` with debug APKs — uninstall first if `install -r` fails.

### Key design decisions

- **Sound catalogue** lives entirely in `ZapSoundLibrary.all` (`sound_model.dart`). Free sounds `s1`–`s5`; premium `p1`–`p144` (gaps at `p30`–`p32`, `p35`, `p36`, `p121`: removed, never reuse) plus `custom`. `p26`–`p144` are an imported "fun pack" (memes, voices, laughs, farts, screams, animals…) — trimmed, loudness-matched (−16 dBFS RMS, −1 dB limiter), capped at 6 s, mono 128 kbps mp3, named `<category>_<name>.mp3`. Chip/section order comes from `ZapSoundLibrary.categoryOrder` (Classic, Funny, Memes, Voices, Laughs, Farts, Gross, Screams, Animals, Cartoon, Spooky, Gaming, Action, Retro, Sci-Fi, Music, Chill, Custom); new categories also need `categoryIcon()` / `hueForCategory()` cases. Adding a sound = add the `SoundModel` entry, drop the `.wav`/`.mp3` into `assets/sounds/`, copy it to `res/raw/`. **No Kotlin edit needed**: on selection Dart persists both the id (`plug_in_sound`, UI state) and the file basename (`plug_in_file`, read natively) via `SoundModel.fileName` (basename, any extension stripped). Several sounds were synthesized with a stdlib-Python script (44.1 kHz 16-bit mono PCM).
- **`SoundTarget` enum** (`plugIn` / `plugOut` / `batteryFull`) parameterizes `SoundPickerScreen`; the batteryFull target hides the custom-recording row and persists via `setBatteryFullSound(id, file)`.
- **Anti-theft (premium)** — armed via Home toggle (PIN set on first arm through `showPinSetupDialog`; changeable in Settings → Unplug alarm). Prefs: `antitheft_armed`, `antitheft_pin`. The Dart MethodChannel handler skips the unplug sound while armed; the native receiver handles the siren + PIN screen. Disarms itself after each triggered alarm.
- **Premium gate** is a boolean in SharedPreferences (`is_premium`). `PurchaseService.init()` must be called before `runApp`; it maps every `purchaseStream` status to a `PurchaseEvent` (purchased/pending/canceled/error) on the broadcast `PurchaseService.events`, which the paywall listens to only while a buy is in flight, and acknowledges purchases (`completePurchase`, else Play refunds after 3 days). `buy()` returns a `BuyStart` (launched / storeUnavailable / alreadyOwned → auto-restore / failed). At startup `syncWithStore()` (via `InAppPurchaseAndroidPlatformAddition.queryPastPurchases`, direct dep `in_app_purchase_android`) grants + acknowledges purchases completed while closed (pending payments) and **revokes premium after refunds**; it leaves the flag alone on any store error so offline users keep premium. `restoreAndCheck()` syncs, then restores and polls `isPremium` (10 × 400 ms). The Home banner and paywall both show the live store price via `getProduct()` (fallback `$2.99`).
- **Battery status on Home** — `BatteryService.getStatus()` (null if the channel fails). The hero ring (`_BatteryRingPainter`) shows level with a brand-gradient sweep; refreshed by a 15 s timer plus `BatteryService.chargerEvents`, a `ValueNotifier` bumped by the `main.dart` MethodChannel handler on plug/unplug. "Plugged in" is derived from `plugType` (`isPluggedIn`), not `isCharging`.
- **Previews await real playback**: just_audio's `play()` future completes when the sound ends or `AudioService.stop()` is called — no fixed delays. Tapping an active preview stops it.
- **Custom sound** (id `custom`) stores a file path in prefs (`custom_in_path` / `custom_out_path`); can be re-recorded or removed in the picker (removal deletes the file and reverts selection to `s1`/`s2` + file mirror).
- **Master enable toggle** — `zapsound_enabled` pref (default `true`); checked in the `main.dart` handler, `ZapReceiver`, and the battery-full receiver. The Home ring "tap to test" bypasses it (hit area is clipped to the ring's circle via an `onTapUp` distance check — a plain `onTap` would fire on the corners of the 224×224 box).
- **Volume** — `volume_pct` pref (int 0–100, default 100). Applied in `AudioService` (`setVolume` before play) and natively in `ZapSoundPlayer` (reads `flutter.volume_pct` as Long — shared_preferences stores Dart ints as Long). Settings slider previews the plug-in sound on release.
- **Quiet hours** — `quiet_hours_enabled` / `quiet_start_min` / `quiet_end_min` prefs (defaults off, 22:00→07:00; window may wrap midnight). Checked in the `main.dart` handler (`PrefsService.isQuietNow()`) and natively (`ZapSoundPlayer.isQuietNow()`, used by `ZapReceiver` + battery-full receiver). Anti-theft siren intentionally ignores it.
- **Settings sections** — Pro status (premium only) → Sound (volume, quiet hours) → Unplug alarm (Change PIN, premium only) → Appearance (theme) → Background → Purchase (hidden when premium) → About. Battery-full toggle + sound live on Home, not Settings. `_Tile` takes a nullable `onTap`; `null` hides the chevron (Version row). About links (via `url_launcher`): Rate opens `market://details?id=com.zapsound.app` (web fallback), Share includes the Play URL, Privacy opens `https://nktushar.github.io/zapsound/privacy_policy.html` — requires GitHub Pages enabled on `main` → `/docs`.
- **Theme toggling** — `_ZapSoundAppState` owns a `ValueNotifier<ThemeMode>`; `SettingsScreen` persists via `PrefsService.setThemeMode` and live-updates via `ZapSoundApp.of(context)?.setThemeMode(parseThemeMode(..))`.
- **Onboarding** — `main()` reads `isOnboarded` and sets `home` accordingly; reset by clearing the `onboarding_done` pref.
- **HomeScreen uses `resizeToAvoidBottomInset: false`** — the fixed hero layout must not squash when a dialog keyboard opens.
