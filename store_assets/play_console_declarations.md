# Play Console declarations — ZapSound (`com.zapsound.app`)

Paste-ready answers for Play Console → **App content** (Policy → App content).
Menu labels drift between Console versions; match by topic. Keep every answer
true to the shipped build — if a feature changes, update this file.

---

## 1. Foreground service permissions (`FOREGROUND_SERVICE_SPECIAL_USE`)

**Where:** App content → Foreground service permissions → select **Special use**.

**Feature description (what the service does):**

> ZapSound plays a sound the user chose when the phone's charger is plugged in or unplugged, and when the battery reaches 100% while charging. It also offers an optional anti-theft alarm that sounds if the charger is unplugged while armed. Android only delivers charger plug/unplug broadcasts (ACTION_POWER_CONNECTED / ACTION_POWER_DISCONNECTED) to receivers registered at runtime, so a running service is required to register that receiver and listen for these events while the app is closed. The service does no network, location or data work; it only listens for power events and plays a short local sound.

**Why other foreground service types don't fit:**

> No standard type covers listening for system power events. dataSync is incorrect (no data is transferred) and on Android 15+ is limited to 6 hours per day and cannot start after boot, which would stop the feature working. mediaPlayback doesn't fit because nothing plays most of the time; sounds are short (under 6 seconds) and only triggered by charger events.

**User impact if the task is deferred or interrupted:**

> The sound would play late or not at all, which defeats the feature: the user plugs in and hears nothing. For the anti-theft alarm, a delayed or missed siren means a thief can unplug and take the phone without the alarm sounding.

**Is the task started by the user?**

> Yes. The user enables charger sounds on first launch and can turn them off at any time with the master switch on the home screen, which stops all sounds. The service shows a persistent low-priority notification while running.

**Video link (required):** record a 30–60 s screen capture, upload as *unlisted* YouTube, paste link. Script:
1. Open ZapSound → show the home screen and master switch ON.
2. Pick a plug-in sound in the picker.
3. Swipe the app away from Recents (app closed).
4. Plug the charger in → sound plays (have audio recorded, or show captions).
5. Unplug → unplug sound plays.
6. Pull down the shade → show the "ZapSound" foreground notification.
7. (Optional) Arm the unplug alarm, lock the screen, unplug → siren + PIN screen.

*Tip: on an emulator, `adb shell dumpsys battery set ac 1` / `set ac 0` simulates plug/unplug.*

The manifest subtype (`PROPERTY_SPECIAL_USE_FGS_SUBTYPE`) already matches this text.

---

## 2. Full-screen intent (`USE_FULL_SCREEN_INTENT`, Android 14+)

**Where:** App content → Full-screen intent permission.

**Choose:** *"Your app's core functionality is setting alarms"* (or the alarm-related option shown). Do **not** choose calling.

**Justification:**

> ZapSound includes a user-armed anti-theft alarm. When armed and the charger is unplugged, the app sounds a loud siren and must immediately show a full-screen PIN screen over the lock screen so the owner can enter their PIN to silence it. This behaves like an alarm clock: the user explicitly arms it, it rings at full volume, and it needs to appear over the lock screen right away. The full-screen intent is used for this alarm only, never for promotions or regular notifications.

**If Google denies it:** the app still works. On Android 14+ without the permission, the siren starts anyway and the alarm notification's tap action opens the PIN screen (already implemented in `ZapReceiver.showAlarmScreen`; Home prompts the user to allow it in Settings after arming). Remove the permission from the manifest only if the declaration is rejected outright.

---

## 3. `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

**There is no Console form for this.** It's reviewed under the *Device and Network Abuse* policy, and Google only allows it for specific use cases. If review flags it, reply with:

> ZapSound's core function is reacting instantly to an external hardware event (charger plug/unplug) with a user-chosen sound, plus an optional anti-theft alarm. Many manufacturers (Xiaomi, Oppo, Vivo, Samsung and others) kill background apps even when a foreground service is running, which silently breaks both features. We ask once, with an explanation, during first-launch setup; the user can decline and the app keeps working with reduced reliability. The app does no background network or data work, so the exemption doesn't drain the battery: it only listens for power broadcasts and plays a short local sound when one arrives.

**If rejected anyway:** remove the permission and switch `requestBatteryOptimizationExemption()` in `MainActivity.kt` to open `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` (the battery settings list), which needs no permission. Settings → Background already has an OEM help sheet to go with it.

---

## 4. Content rating questionnaire (IARC)

**Category:** Utility / Productivity (not Game).

Answer **truthfully** based on the sound library:

| Question topic | Answer | Why |
|---|---|---|
| Violence | Yes (mild, non-graphic sound effects only) | Gunshots, machine gun, glass smash: audio only, no images |
| Fear / horror | Yes (mild) | Spooky pack: evil laugh, jump scare, creepy whispers |
| Sexual content / suggestive themes | Yes (suggestive, no nudity) | "Yamete Kudasai" meme clips |
| Crude humour | Yes | Fart, burp, vomit sounds |
| Profanity / strong language | No | F-Bomb clip removed |
| Drugs / alcohol / tobacco | No | |
| Gambling | No | |
| User interaction / user-generated content shared with others | No | Custom recordings stay on the device; nothing is shared |
| Shares user location | No | |
| Digital purchases | Yes | One-time in-app purchase (Pro) |

Expected result: roughly **ESRB Teen / PEGI 12**. Don't under-declare; a mismatch found later can lead to removal.

---

## 5. Target audience and content

**Target age groups:** **13–15, 16–17, 18+** only. Do **not** select any group under 13 (suggestive content plus under-13 = Families policy violation).

**Could the app unintentionally appeal to children?** Answer **No**, and keep the store listing neutral: don't show the Yamete Kudasai or fart sounds in screenshots, the feature graphic or the short description.

---

## 6. Data safety

| Topic | Answer |
|---|---|
| Does the app collect or share user data? | **No** |
| Audio (microphone) | Recorded only when the user taps Record; saved in app-private storage on the device; never uploaded. Processing only on the device doesn't count as "collection". |
| Purchases | Handled by Google Play Billing; the app has no server and stores only a local "premium" flag. |
| Encryption in transit | Not applicable (no data transmitted) |
| Data deletion | Users can delete recordings in the app (sound picker → remove) or by clearing app data / uninstalling. |

**Privacy policy URL:** `https://nktushar.github.io/zapsound/privacy_policy.html` (make sure GitHub Pages is enabled on `main` → `/docs` before submitting).

---

## 7. Other App content items

- **Ads:** No ads.
- **Government app / financial features / health:** No.
- **News app:** No.
- **App access:** All features are reachable without login. For Pro features, tell reviewers: *"Pro features (premium sounds, unplug alarm, custom recording) need the one-time in-app purchase. All locked sounds can still be previewed; Google Play's license testers can buy it for free."* Add the reviewer's account as a license tester under Setup → License testing.
