# ZapSound: Background Reliability, Premium Gating, Voice Recording, Icon & Release Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make charger-sound playback work reliably when the app is backgrounded/closed, let users preview (but not select) premium sounds for free, add a working voice-recording feature for custom sounds, ship a real ZapSound app icon, and document the Play Store release process.

**Architecture:** Five independent parts, each touching a different layer (Android native, Flutter UI/prefs, new recording service+screen, asset/icon pipeline, release config/docs). Parts can be executed in order; Part 1 (native) and Part 2 (premium gating) are independent of each other.

**Tech Stack:** Flutter 3.x, Kotlin (Android native), `just_audio`, new packages `record` + `path_provider` + `flutter_launcher_icons`.

---

## Context

The user reports that when ZapSound is closed/minimized, plugging/unplugging the charger produces no sound. A WIP native implementation already exists (uncommitted): `ZapReceiver.kt`, `ZapForegroundService.kt`, manifest receiver/service entries, and `android/app/src/main/res/raw/*.wav` (15 files matching `ZapSoundLibrary`).

**Investigation result:** the WIP is fundamentally correct —
- The manifest intent-filter actions (`android.intent.action.ACTION_POWER_CONNECTED` / `...ACTION_POWER_DISCONNECTED`) are the **real Android constant values** for `Intent.ACTION_POWER_CONNECTED`/`ACTION_POWER_DISCONNECTED` (Android's API has the doubled `ACTION_` in the string itself — this is correct, not a typo).
- `ACTION_POWER_CONNECTED`/`ACTION_POWER_DISCONNECTED` are in Android's documented exemption list for manifest-declared broadcast receivers, so they fire even when the app process isn't running (just not if the user has *force-stopped* the app — that's an unfixable OS restriction).
- `res/raw/*.wav` already matches `soundIdToResName()` in `ZapReceiver.kt` 1:1.

So the remaining work for Part 1 is small hardening + a way for users to fix OEM battery-optimization issues themselves, plus a manual test pass to confirm it actually works end-to-end (this WIP has likely never been built/run on a device).

The other three feature asks (premium preview, voice recording, app icon) are net-new, and Part 5 documents the release process.

---

## Part 1: Background charger reliability

**Files:**
- Modify: `android/app/src/main/kotlin/com/zapsound/app/ZapReceiver.kt`
- Modify: `android/app/src/main/kotlin/com/zapsound/zapsound_fresh/MainActivity.kt`
- Modify: `lib/screens/settings_screen.dart`

### Task 1.1: Self-healing — restart the keepalive service on every charger event

If `ZapForegroundService` was killed by the OS (Doze, memory pressure, Android 14's 6h dataSync limit), the next `POWER_CONNECTED`/`POWER_DISCONNECTED` broadcast should restart it so future events stay reliable.

- [ ] **Step 1: Edit `ZapReceiver.kt` onReceive() to restart the service on power events**

In `/Users/nktushar/Desktop/zapsound_fresh/android/app/src/main/kotlin/com/zapsound/app/ZapReceiver.kt`, change:

```kotlin
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        when (intent.action) {
            Intent.ACTION_POWER_CONNECTED -> play(
                context,
                soundId    = prefs.getString("flutter.plug_in_sound",  "s1") ?: "s1",
                customPath = prefs.getString("flutter.custom_in_path",  null),
            )
            Intent.ACTION_POWER_DISCONNECTED -> play(
                context,
                soundId    = prefs.getString("flutter.plug_out_sound", "s2") ?: "s2",
                customPath = prefs.getString("flutter.custom_out_path", null),
            )
        }
```

to:

```kotlin
        ZapForegroundService.start(context)

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        when (intent.action) {
            Intent.ACTION_POWER_CONNECTED -> play(
                context,
                soundId    = prefs.getString("flutter.plug_in_sound",  "s1") ?: "s1",
                customPath = prefs.getString("flutter.custom_in_path",  null),
            )
            Intent.ACTION_POWER_DISCONNECTED -> play(
                context,
                soundId    = prefs.getString("flutter.plug_out_sound", "s2") ?: "s2",
                customPath = prefs.getString("flutter.custom_out_path", null),
            )
        }
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/nktushar/Desktop/zapsound_fresh && flutter analyze`
Expected: no new errors.

### Task 1.2: Native method channel handler for re-requesting battery optimization exemption

Today the battery-optimization dialog only fires once, on first launch (`maybeRunFirstLaunchSetup`). If the user taps "Not now" or it gets dismissed, there's no way back in. Add a channel method the Settings screen can call anytime.

- [ ] **Step 1: Extract a reusable exemption-request method and wire up a MethodCallHandler**

In `/Users/nktushar/Desktop/zapsound_fresh/android/app/src/main/kotlin/com/zapsound/zapsound_fresh/MainActivity.kt`, replace `configureFlutterEngine`:

```kotlin
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }
```

with:

```kotlin
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                else -> result.notImplemented()
            }
        }
    }
```

Then add the new method and reuse it from `showBatteryDialog()`. Replace:

```kotlin
            .setPositiveButton("OK") { _, _ ->
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                requestRecordAudioPermission()
            }
```

with:

```kotlin
            .setPositiveButton("OK") { _, _ ->
                requestBatteryOptimizationExemption()
                requestRecordAudioPermission()
            }
```

and add this new method anywhere inside the class (e.g. just above `requestRecordAudioPermission`):

```kotlin
    private fun requestBatteryOptimizationExemption() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/nktushar/Desktop/zapsound_fresh && flutter analyze`
Expected: no new errors.

### Task 1.3: Settings screen — "Background & Reliability" section

- [ ] **Step 1: Add the MethodChannel import and a new section to `settings_screen.dart`**

In `/Users/nktushar/Desktop/zapsound_fresh/lib/screens/settings_screen.dart`, add the import at the top:

```dart
import 'package:flutter/services.dart';
```

Then insert a new section between the "Appearance" section and the "Purchase" section (after the closing `]),` of the Appearance `_Section`, before `const SizedBox(height: ZapTheme.space4),` that precedes "Purchase"):

```dart
        const SizedBox(height: ZapTheme.space4),

        _Section('Background & Reliability', [
          _Tile(Icons.battery_charging_full_rounded, 'Allow background activity',
              'Required so charger sounds play when ZapSound is closed', () async {
            const channel = MethodChannel('com.zapsound.app/charger');
            await channel.invokeMethod('requestBatteryOptimizationExemption');
          }),
          _Tile(Icons.smartphone_rounded, 'Some phones need extra setup',
              'Tap for Xiaomi / Oppo / Vivo / Samsung instructions', () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Extra setup for some phones'),
                content: const Text(
                  'On Xiaomi (MIUI), Oppo (ColorOS), Vivo (FuntouchOS) and some '
                  'Samsung phones, Android\'s standard battery settings are not '
                  'enough. Also open:\n\n'
                  '• Settings → Apps → ZapSound → Battery → "No restrictions" / '
                  '"Allow background activity"\n'
                  '• Settings → Apps → Autostart (or "Auto-launch") → enable ZapSound\n\n'
                  'Without this, the OS may stop ZapSound from detecting the '
                  'charger while the app is closed.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
                ],
              ),
            );
          }),
        ]),
```

- [ ] **Step 2: Verify it compiles and renders**

Run: `cd /Users/nktushar/Desktop/zapsound_fresh && flutter analyze`
Expected: no new errors.

Run: `flutter run` and open Settings — confirm the new "Background & Reliability" section appears with both tiles, and tapping the first opens the system battery-optimization dialog (or does nothing if already exempted), and the second opens the info dialog.

### Task 1.4: Manual end-to-end verification on emulator/device

This is the real fix validation — confirm sound now plays in all app states.

- [ ] **Step 1: Build and install the debug app**

```bash
cd /Users/nktushar/Desktop/zapsound_fresh
flutter run -d android
```

- [ ] **Step 2: Foregrounded test**

With the app open and on the home screen, run:
```bash
adb -e shell dumpsys battery set ac 1
```
Expected: plug-in sound plays (via MethodChannel + `AudioService`).
```bash
adb -e shell dumpsys battery set ac 0
```
Expected: unplug sound plays.

- [ ] **Step 3: Backgrounded test**

Press the device Home button (don't kill the app), then repeat:
```bash
adb -e shell dumpsys battery set ac 1
adb -e shell dumpsys battery set ac 0
```
Expected: both sounds play via `ZapReceiver` + `res/raw` `MediaPlayer`.

- [ ] **Step 4: Swiped-away (process killed) test**

Swipe the app away from the recents list (or `adb shell am kill com.zapsound.zapsound_fresh` — note `am kill` only works if the process is in the background/cached state), then repeat:
```bash
adb -e shell dumpsys battery set ac 1
adb -e shell dumpsys battery set ac 0
```
Expected: both sounds still play (manifest receiver spins up a short-lived process).

- [ ] **Step 5: Reset emulator battery state**

```bash
adb -e shell dumpsys battery reset
```

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/zapsound/app/ZapReceiver.kt \
        android/app/src/main/kotlin/com/zapsound/zapsound_fresh/MainActivity.kt \
        lib/screens/settings_screen.dart
git commit -m "fix: harden background charger detection and add reliability settings"
```

---

## Part 2: Premium sounds — preview for everyone, select only after purchase

**Files:**
- Modify: `lib/screens/sound_picker_screen.dart`

Current behavior: premium sounds hide the preview button entirely for non-premium users (`if (s.isPremium && !widget.isPremium) return;` in `_preview`, and the preview button is only rendered `if (!locked)`). Selection is already correctly blocked (`_select` redirects to `PremiumScreen`). We only need to change preview.

### Task 2.1: Allow preview playback for locked (premium) sounds

- [ ] **Step 1: Remove the premium guard in `_preview`**

In `/Users/nktushar/Desktop/zapsound_fresh/lib/screens/sound_picker_screen.dart`, change:

```dart
  Future<void> _preview(SoundModel s) async {
    if (s.isPremium && !widget.isPremium) return;
    setState(() => _playingId = s.id);
    await AudioService.playAsset(s.assetPath);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _playingId = null);
  }
```

to:

```dart
  Future<void> _preview(SoundModel s) async {
    if (s.assetPath.isEmpty) return; // 'custom' has no bundled asset to preview here
    setState(() => _playingId = s.id);
    await AudioService.playAsset(s.assetPath);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _playingId = null);
  }
```

- [ ] **Step 2: Always render the preview button, and show a lock badge alongside it for locked sounds**

In the same file, replace the "Action button" block:

```dart
                      // Action button
                      if (locked)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ZapColors.gold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                          ),
                          child: const Icon(Icons.lock_rounded, size: 16, color: ZapColors.gold),
                        )
                      else
                        GestureDetector(
                          onTap: () => _preview(s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: playing ? ZapColors.primary : ZapColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                            ),
                            child: Icon(
                              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                              color: playing ? Colors.white : ZapColors.primary,
                              size: 20,
                            ),
                          ),
                        ),

                      if (!locked) ...[
                        const SizedBox(width: 10),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: selected ? 1.0 : 0.0,
                          child: const Icon(Icons.check_circle_rounded, color: ZapColors.primary, size: 22),
                        ),
                      ],
```

with:

```dart
                      // Action button
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (s.assetPath.isNotEmpty)
                          GestureDetector(
                            onTap: () => _preview(s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: playing ? ZapColors.primary : ZapColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                              ),
                              child: Icon(
                                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: playing ? Colors.white : ZapColors.primary,
                                size: 20,
                              ),
                            ),
                          ),

                        if (locked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ZapColors.gold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                            ),
                            child: const Icon(Icons.lock_rounded, size: 16, color: ZapColors.gold),
                          ),
                        ] else ...[
                          const SizedBox(width: 10),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: selected ? 1.0 : 0.0,
                            child: const Icon(Icons.check_circle_rounded, color: ZapColors.primary, size: 22),
                          ),
                        ],
                      ]),
```

- [ ] **Step 3: Verify**

Run: `cd /Users/nktushar/Desktop/zapsound_fresh && flutter analyze`
Expected: no new errors.

Run: `flutter run`, open the sound picker as a non-premium user. Confirm:
- Free sounds: play button + checkmark, tap plays preview, tap card selects.
- Premium sounds: play button (now visible) + gold lock badge. Tapping play button previews the sound. Tapping the card body still opens `PremiumScreen` (selection still blocked).
- `custom` ("My Recording", `assetPath: ''`): no play button shown (handled in Part 3), lock badge shown if not premium.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/sound_picker_screen.dart
git commit -m "feat: allow previewing premium sounds without purchase"
```

---

## Part 3: Voice recording feature

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/recording_service.dart`
- Create: `lib/screens/record_sound_screen.dart`
- Modify: `lib/screens/sound_picker_screen.dart`
- Modify: `ios/Runner/Info.plist`

### Task 3.1: Add recording dependencies

- [ ] **Step 1: Add `record` and `path_provider` to `pubspec.yaml`**

In `/Users/nktushar/Desktop/zapsound_fresh/pubspec.yaml`, under `dependencies:`, add after `flutter_animate: ^4.3.0`:

```yaml
  record: ^5.1.2
  path_provider: ^2.1.4
```

- [ ] **Step 2: Install**

```bash
cd /Users/nktushar/Desktop/zapsound_fresh && flutter pub get
```
Expected: resolves successfully, `pubspec.lock` updated.

### Task 3.2: `RecordingService`

- [ ] **Step 1: Create `/Users/nktushar/Desktop/zapsound_fresh/lib/services/recording_service.dart`**

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  static final _recorder = AudioRecorder();

  static Future<bool> hasPermission() => _recorder.hasPermission();

  static Future<bool> isRecording() => _recorder.isRecording();

  static Future<void> start() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/zap_recording_tmp.m4a';
    final tmp = File(path);
    if (await tmp.exists()) await tmp.delete();
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
  }

  static Future<String?> stop() => _recorder.stop();

  /// Copies the temp recording to a stable filename (e.g. "custom_in" / "custom_out")
  /// and returns the final path to persist in preferences.
  static Future<String> saveAs(String tempPath, String finalName) async {
    final dir = await getApplicationDocumentsDirectory();
    final finalPath = '${dir.path}/$finalName.m4a';
    final existing = File(finalPath);
    if (await existing.exists()) await existing.delete();
    final saved = await File(tempPath).copy(finalPath);
    return saved.path;
  }

  static void dispose() => _recorder.dispose();
}
```

### Task 3.3: `RecordSoundScreen`

- [ ] **Step 1: Create `/Users/nktushar/Desktop/zapsound_fresh/lib/screens/record_sound_screen.dart`**

```dart
import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

class RecordSoundScreen extends StatefulWidget {
  final bool isPlugIn;
  const RecordSoundScreen({super.key, required this.isPlugIn});

  @override
  State<RecordSoundScreen> createState() => _RecordSoundScreenState();
}

class _RecordSoundScreenState extends State<RecordSoundScreen> {
  bool _recording = false;
  bool _playing = false;
  String? _recordedPath;
  String? _error;

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await RecordingService.stop();
      setState(() {
        _recording = false;
        _recordedPath = path;
      });
      return;
    }
    if (!await RecordingService.hasPermission()) {
      setState(() => _error = 'Microphone permission is required to record.');
      return;
    }
    setState(() {
      _error = null;
      _recordedPath = null;
    });
    await RecordingService.start();
    setState(() => _recording = true);
  }

  Future<void> _preview() async {
    if (_recordedPath == null) return;
    setState(() => _playing = true);
    await AudioService.playFile(_recordedPath!);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _save() async {
    if (_recordedPath == null) return;
    final name = widget.isPlugIn ? 'custom_in' : 'custom_out';
    final finalPath = await RecordingService.saveAs(_recordedPath!, name);
    if (widget.isPlugIn) {
      await PrefsService.setCustomIn(finalPath);
      await PrefsService.setPlugIn('custom');
    } else {
      await PrefsService.setCustomOut(finalPath);
      await PrefsService.setPlugOut('custom');
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    if (_recording) RecordingService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPlugIn ? 'Record Plug-in Sound' : 'Record Unplug Sound',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: _toggleRecord,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recording ? Colors.red : ZapColors.primary,
              ),
              child: Icon(
                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: ZapTheme.space4),
          Text(
            _recording
                ? 'Recording... tap to stop'
                : (_recordedPath == null ? 'Tap to record' : 'Recorded!'),
            style: const TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w600),
          ),
          if (_error != null) ...[
            const SizedBox(height: ZapTheme.space2),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: ZapTheme.textSm)),
          ],
          if (_recordedPath != null && !_recording) ...[
            const SizedBox(height: ZapTheme.space4),
            TextButton.icon(
              onPressed: _preview,
              icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_playing ? 'Playing...' : 'Preview'),
            ),
            const SizedBox(height: ZapTheme.space4),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZapColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusLg)),
                ),
                child: const Text('Save & Use', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
```

`ZapTheme.space2` (= 8.0) and `space3` (= 12.0) are both defined in `/Users/nktushar/Desktop/zapsound_fresh/lib/theme/app_theme.dart` — used as-is above.

### Task 3.4: Wire "My Recording" into the sound picker

- [ ] **Step 1: Handle `custom` in `_preview` and `_select`**

In `/Users/nktushar/Desktop/zapsound_fresh/lib/screens/sound_picker_screen.dart`, add the import:

```dart
import 'record_sound_screen.dart';
```

Update `_preview` (from Part 2's version) to handle `custom`:

```dart
  Future<void> _preview(SoundModel s) async {
    if (s.id == 'custom') {
      final path = widget.isPlugIn ? await PrefsService.getCustomIn() : await PrefsService.getCustomOut();
      if (path == null) return;
      setState(() => _playingId = s.id);
      await AudioService.playFile(path);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _playingId = null);
      return;
    }
    if (s.assetPath.isEmpty) return;
    setState(() => _playingId = s.id);
    await AudioService.playAsset(s.assetPath);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _playingId = null);
  }
```

Update `_select` to open `RecordSoundScreen` for `custom`:

```dart
  Future<void> _select(SoundModel s) async {
    if (s.isPremium && !widget.isPremium) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
      return;
    }
    if (s.id == 'custom') {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => RecordSoundScreen(isPlugIn: widget.isPlugIn)),
      );
      if (saved == true && mounted) Navigator.pop(context);
      return;
    }
    setState(() => _selectedId = s.id);
    if (widget.isPlugIn) await PrefsService.setPlugIn(s.id);
    else await PrefsService.setPlugOut(s.id);
    if (mounted) Navigator.pop(context);
  }
```

- [ ] **Step 2: Show a mic icon (not a play button) for the `custom` card**

In the "Action button" `Row` from Part 2, the condition `if (s.assetPath.isNotEmpty)` already hides the play button for `custom` (its `assetPath` is `''`). Add a mic-icon affordance instead by changing that condition block to:

```dart
                        if (s.assetPath.isNotEmpty)
                          GestureDetector(
                            onTap: () => _preview(s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: playing ? ZapColors.primary : ZapColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                              ),
                              child: Icon(
                                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: playing ? Colors.white : ZapColors.primary,
                                size: 20,
                              ),
                            ),
                          )
                        else if (s.id == 'custom' && !locked)
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: ZapColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                            ),
                            child: const Icon(Icons.mic_rounded, color: ZapColors.primary, size: 20),
                          ),
```

- [ ] **Step 3: Verify**

Run: `cd /Users/nktushar/Desktop/zapsound_fresh && flutter analyze`
Expected: no new errors.

### Task 3.5: iOS microphone permission string

- [ ] **Step 1: Add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`**

Read `/Users/nktushar/Desktop/zapsound_fresh/ios/Runner/Info.plist`, and inside the top-level `<dict>` add:

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>ZapSound needs microphone access to record a custom charger sound.</string>
```

### Task 3.6: Manual test + commit

- [ ] **Step 1: Run on device/emulator**

```bash
cd /Users/nktushar/Desktop/zapsound_fresh && flutter run -d android
```

- [ ] **Step 2: Manual test as a premium user** (use a debug build where `PrefsService.setPremium(true)` is set, or temporarily flip it via the Premium screen / `flutter inspector`)

1. Open sound picker for "Plug-in sound" → tap "My Recording" card.
2. Record screen opens → tap mic → speak → tap stop → tap "Preview" (hear playback) → tap "Save & Use".
3. Back on Home, the Plug-in sound card should now show "My Recording".
4. Tap "Tap to test" (zap button) → confirm the recorded sound plays.
5. Repeat for "Unplug sound" with a different recording, confirm both `custom_in.m4a` and `custom_out.m4a` exist under the app's documents dir and play independently.

- [ ] **Step 3: Manual test as a non-premium user**

1. Open sound picker → "My Recording" card shows the gold lock badge.
2. Tapping the card opens `PremiumScreen` (cannot record/select without purchase) — matches Part 2 behavior since `custom.isPremium == true`.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/recording_service.dart \
        lib/screens/record_sound_screen.dart lib/screens/sound_picker_screen.dart \
        ios/Runner/Info.plist
git commit -m "feat: add voice recording for custom charger sounds"
```

---

## Part 4: Replace the app icon with a ZapSound icon

**Files:**
- Create: `assets/icon/icon.png`, `assets/icon/icon_foreground.png`
- Modify: `pubspec.yaml`
- Generated (do not hand-edit): `android/app/src/main/res/mipmap-*/ic_launcher.png`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`, etc.

No existing logo/icon source exists in the repo, so we generate one programmatically (a lightning bolt on the app's brand purple, matching `ZapColors.primary` = `#6C63FF` used throughout the UI).

### Task 4.1: Generate icon source images

- [ ] **Step 1: Create the icon-generation script**

Create `/Users/nktushar/Desktop/zapsound_fresh/assets/icon/generate_icon.py`:

```python
from PIL import Image, ImageDraw

SIZE = 1024
PRIMARY = (108, 99, 255, 255)   # #6C63FF — ZapColors.primary
WHITE = (255, 255, 255, 255)

# Lightning bolt polygon, designed on a 100x100 grid, scaled to SIZE.
BOLT = [
    (58, 4), (28, 52), (48, 52), (40, 96), (74, 44), (54, 44), (58, 4),
]

def bolt_points(scale, offset=(0, 0)):
    return [(x * scale / 100 + offset[0], y * scale / 100 + offset[1]) for x, y in BOLT]

# 1. Full icon: rounded square background + white bolt (for ic_launcher / iOS)
icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(icon)
d.rounded_rectangle([0, 0, SIZE, SIZE], radius=SIZE // 5, fill=PRIMARY)
d.polygon(bolt_points(SIZE), fill=WHITE)
icon.save("icon.png")

# 2. Foreground-only bolt (transparent bg) for Android adaptive icons.
#    Adaptive icons are center-cropped, so keep the bolt within the safe ~66% zone.
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(fg)
scale = SIZE * 0.55
offset = ((SIZE - scale) / 2, (SIZE - scale) / 2)
d.polygon(bolt_points(scale, offset), fill=WHITE)
fg.save("icon_foreground.png")

print("Wrote icon.png and icon_foreground.png")
```

- [ ] **Step 2: Run it**

```bash
cd /Users/nktushar/Desktop/zapsound_fresh/assets/icon
python3 -c "import PIL" 2>/dev/null || pip3 install pillow
python3 generate_icon.py
```
Expected: `icon.png` and `icon_foreground.png` (both 1024x1024) created in `assets/icon/`.

### Task 4.2: Configure `flutter_launcher_icons`

- [ ] **Step 1: Add the dev dependency and config to `pubspec.yaml`**

In `/Users/nktushar/Desktop/zapsound_fresh/pubspec.yaml`, under `dev_dependencies:`, add:

```yaml
  flutter_launcher_icons: ^0.13.1
```

Then add a new top-level section (after the `flutter:` block):

```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#6C63FF"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  min_sdk_android: 21
  remove_alpha_ios: true
```

- [ ] **Step 2: Install and generate**

```bash
cd /Users/nktushar/Desktop/zapsound_fresh
flutter pub get
dart run flutter_launcher_icons
```
Expected output ends with something like `✓ Successfully generated launcher icons`.

- [ ] **Step 3: Verify generated files**

```bash
file android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
ls android/app/src/main/res/mipmap-anydpi-v26/ 2>/dev/null
```
Expected: 192x192 PNG for xxxhdpi; an adaptive-icon XML present if adaptive icons were generated.

### Task 4.3: Manual verification + commit

- [ ] **Step 1: Rebuild and check the icon on-device**

```bash
flutter run -d android
```
Expected: launcher icon and the `ZapForegroundService` notification icon (`R.mipmap.ic_launcher`, see `/Users/nktushar/Desktop/zapsound_fresh/android/app/src/main/kotlin/com/zapsound/app/ZapForegroundService.kt:61`) both show the new bolt icon.

- [ ] **Step 2: Commit**

```bash
git add assets/icon/ pubspec.yaml pubspec.lock android/app/src/main/res ios/Runner/Assets.xcassets
git commit -m "feat: replace default app icon with ZapSound bolt icon"
```

---

## Part 5: Play Store deployment plan

This part is documentation/config only — a checklist plus the concrete config changes needed before a release build can be signed and uploaded.

**Files:**
- Create: `android/key.properties` (untracked, local-only)
- Modify: `android/app/build.gradle.kts`
- Modify: `.gitignore`
- Modify: `pubspec.yaml` (version bump, per release)

### Task 5.1: Create an upload keystore (one-time, local)

- [ ] **Step 1: Generate the keystore**

```bash
cd /Users/nktushar/Desktop/zapsound_fresh/android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias zapsound
```
Follow the prompts (set a password, organization details). **Store the resulting `upload-keystore.jks` and its passwords somewhere safe outside the repo** (e.g. a password manager) — losing it means you can never update the app again under the same listing.

- [ ] **Step 2: Create `android/key.properties`** (do not commit)

```properties
storePassword=<password you set above>
keyPassword=<password you set above>
keyAlias=zapsound
storeFile=upload-keystore.jks
```

- [ ] **Step 3: Add both to `.gitignore`**

In `/Users/nktushar/Desktop/zapsound_fresh/.gitignore`, add:

```
android/key.properties
android/upload-keystore.jks
```

### Task 5.2: Wire the release signing config

- [ ] **Step 1: Update `android/app/build.gradle.kts`**

In `/Users/nktushar/Desktop/zapsound_fresh/android/app/build.gradle.kts`, add near the top (after the `plugins {}` block):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Then replace the `buildTypes` block:

```kotlin
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
```

with:

```kotlin
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
```

- [ ] **Step 2: Verify a release build works**

```bash
cd /Users/nktushar/Desktop/zapsound_fresh
flutter build appbundle --release
```
Expected: `build/app/outputs/bundle/release/app-release.aab` produced, signed with the upload key (check via `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab` if you want to confirm the cert CN matches what you entered in Task 5.1).

- [ ] **Step 3: Commit (excluding secrets)**

```bash
git add android/app/build.gradle.kts .gitignore
git commit -m "build: wire release signing config for Play Store uploads"
```

### Task 5.3: Versioning convention

- [ ] **Step 1: Bump version for each release in `pubspec.yaml`**

`version: 1.0.0+1` → format is `<versionName>+<versionCode>`. Increment `versionCode` (the integer after `+`) on **every** Play Console upload, even for the same `versionName`. E.g. first release `1.0.0+1`, next bugfix upload `1.0.1+2`.

### Task 5.4: Play Console setup checklist (manual, one-time per app)

- [ ] Create the app in Play Console (App name: "ZapSound", default language, Free or Paid — this app uses an in-app purchase so the app itself stays free).
- [ ] **App content** section:
  - Privacy policy URL — `settings_screen.dart` already has a "Privacy policy" tile (`/Users/nktushar/Desktop/zapsound_fresh/lib/screens/settings_screen.dart:69`) that currently does nothing (`() {}`). Before release, host a real privacy policy page and wire this tile to open it (e.g. via `url_launcher`), then paste the same URL into Play Console.
  - Data safety form: declare microphone access (used only locally for custom recordings, not transmitted), and that no personal data is collected/shared (purchases go through Google Play Billing).
  - Content rating questionnaire — likely "Everyone", but flag the "Fart"/"Error"/"Airhorn" sound names if asked about crude humor.
  - **Foreground service permission declaration**: since the app declares `FOREGROUND_SERVICE_DATA_SYNC` (`/Users/nktushar/Desktop/zapsound_fresh/android/app/src/main/AndroidManifest.xml:5`), Play Console's "App content" → "Foreground service permissions" section requires a written justification (e.g. "Keeps a lightweight background listener alive so the app can play a sound when the charger is plugged/unplugged, even while the app is closed.").
  - Target audience & ads — set appropriate age range; declare no ads if none are shown.
- [ ] **Monetization** → **In-app products**: create a managed product with product ID **`zapsound_premium_lifetime`** (must exactly match `/Users/nktushar/Desktop/zapsound_fresh/lib/services/purchase_service.dart:5`), type "One-time purchase", price ~$2.99, status "Active".
- [ ] **Testing**: add internal testers (your Google account + any QA emails) under **Testing → Internal testing**, create a release, upload the `.aab` from Task 5.2, and roll out to the internal track.
- [ ] On a test device signed into a tester account, install from the internal testing link, verify:
  - Charger sounds work in all 3 app states (re-run Part 1's Task 1.4 on the *release* build).
  - The `zapsound_premium_lifetime` purchase flow completes using a Play **license tester** account (test purchases don't charge real money).
  - Voice recording + custom sound selection works (Part 3).
  - App icon shows correctly on the home screen and app drawer (Part 4).
- [ ] **Production**: once internal testing passes, create a Production release with the same `.aab`, fill in the Store Listing (title, short/full description, screenshots — at least 2 phone screenshots and a feature graphic 1024x500), and submit for review.

---

## Final Task: Update CLAUDE.md

- [ ] **Step 1: Update `/Users/nktushar/Desktop/zapsound_fresh/CLAUDE.md`**

After all parts above are implemented, update the "Layer overview" and "Key design decisions" sections to document:
- New files: `lib/services/recording_service.dart`, `lib/screens/record_sound_screen.dart`, `assets/icon/`.
- New dependencies: `record`, `path_provider`, `flutter_launcher_icons`.
- The Settings screen's new "Background & Reliability" section and its native MethodChannel methods (`requestBatteryOptimizationExemption`, `isIgnoringBatteryOptimizations`).
- The premium preview-vs-select distinction in `sound_picker_screen.dart`.
- Release signing setup (`android/key.properties`, gitignored).

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for recording, icon, and reliability changes"
```
