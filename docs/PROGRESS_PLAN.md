# ZapSound — Remaining Work Plan

> Tracking doc for Claude Code + you. Each task has a checkbox. When a task is done, mark `[x]`. Read this file before starting work to know what's next.

## Context

App core works (charger detection, sound library, premium one-time purchase, dark mode). Before release we need: a properly polished recording feature (max 2 custom sounds: plug-in + plug-out, each re-recordable, with good UX/animation), a fully working Settings page, an elevated visual polish pass on the screens that lag behind (`SoundPickerScreen`, `SettingsScreen`, `RecordSoundScreen`), and finally the Play Store release + paid-feature test process. Order below is sequential — finish one phase before starting the next, since later phases (visual polish, release) build on top of earlier ones.

Decisions locked in:
- Recording stays capped at exactly 2 custom slots (plug-in, plug-out) — this is already enforced by the data model (`custom_in_path` / `custom_out_path` in `lib/services/preferences_service.dart`). No schema change needed. Multi-recording / upload-your-own is explicit future scope, not built now.
- Visual polish = elevate weaker screens to match the existing polished look (purple `#6C63FF` / gold `#FFD60A` palette, gradients, `flutter_animate`) already used in `HomeScreen` / `PremiumScreen` / `OnboardingScreen`. Not a from-scratch redesign.
- Settings dead rows (Rate, Share, Privacy) get wired with real logic now, using placeholder content where the real thing doesn't exist yet (no Play Store URL until published).
- Sound picker re-record interaction: tapping the "My Recording" row selects + previews it (consistent with how every other sound row works); a separate small button triggers re-recording.

---

## Phase 1 — Recording feature: proper UX

Files: `lib/screens/record_sound_screen.dart`, `lib/screens/sound_picker_screen.dart`, `lib/services/recording_service.dart`, `lib/models/sound_model.dart`, `lib/theme/app_theme.dart`

- [x] **Live waveform/amplitude animation while recording.** Use `record` package's `onAmplitudeChanged` stream (or poll `AudioRecorder.getAmplitude()`) to drive a bar/wave visualizer around the mic button in `record_sound_screen.dart`, replacing the current static red circle.
- [x] **Recording screen visual polish** — match `HomeScreen`'s gradient/animation language: animated pulsing ring around the mic button while recording, `flutter_animate` entrance for the preview/save buttons, clearer "Recording 0:03" elapsed-time text instead of just a status label.
- [x] **Sound picker row behavior for `custom`**: when a recording already exists for that slot (`PrefsService.getCustomIn()`/`getCustomOut()` non-null), tapping the row selects + previews it like any other sound (reuse existing `_preview` path, extend the `if (s.assetPath.isNotEmpty)` preview-button condition to also cover `s.id == 'custom' && recordingExists`). Add a distinct small re-record icon button (e.g. `Icons.fiber_manual_record` or `Icons.mic_rounded` next to the play button) that explicitly opens `RecordSoundScreen` to overwrite.
- [x] **Visual marker for "this is your recording"**: when a custom recording exists, show a small "Recorded" badge/checkmark style tag distinct from the lock/premium badge, so it's visually obvious which row holds the user's own audio vs the stock library sound.
- [x] **Empty state**: when no recording exists yet for that slot, the row should clearly read as "Tap to record" (e.g. dimmed mic icon + label) rather than looking like a regular sound row with nothing to preview.
- [x] Manual test on device: record plug-in sound, record plug-out sound, confirm both persist independently, re-record one without affecting the other, confirm waveform animates, confirm preview vs re-record buttons both work. (Verified on Android emulator: waveform/pulse/timer animate correctly, save flow persists, re-record reopens recorder, Recorded badge + preview/re-record buttons render without overflow after fixing a row-overflow bug found during testing.)

## Phase 2 — Settings page: finish remaining rows

File: `lib/screens/settings_screen.dart`, `pubspec.yaml`

- [x] Add `share_plus` and `package_info_plus` to `pubspec.yaml`.
- [x] **Version row**: read real app version via `PackageInfo.fromPlatform()` instead of hardcoded `1.0.0` string.
- [x] **Share with friends**: wire to `Share.share(...)` with app name + a placeholder line noting the Play Store link will be added post-launch (track this as a literal `// TODO: add Play Store link after release` comment at the URL spot).
- [x] **Rate ZapSound**: disable/grey out the row with a small "Available after release" subtitle until a real Play Store URL exists; swap in `launchUrl` to the store listing once Phase 4 publishes the app.
- [x] **Privacy policy**: stubbed to a simple placeholder text screen in-app (`_PrivacyPlaceholderScreen`); swap to `url_launcher` + real hosted URL later.
- [x] Dedupe the restore-purchase logic duplicated between `settings_screen.dart` and `premium_screen.dart` — pulled into `PurchaseService.restoreAndCheck()`, called from both screens.
- [x] `flutter analyze` clean (no new warnings/errors).
- [ ] Manual tap-through of every settings row on device — needs to be done on a real device/emulator, not verifiable from this environment.

## Phase 3 — Visual polish pass

Files: `lib/screens/sound_picker_screen.dart`, `lib/screens/settings_screen.dart`, `lib/screens/record_sound_screen.dart` (overlaps Phase 1's polish work), `lib/theme/app_theme.dart`

- [x] `SoundPickerScreen`: add `flutter_animate` staggered entrance for list rows (matches the pattern already used in `home_screen.dart` / `premium_screen.dart`'s `_FeatureRow`), category chip selection animation polish, subtle gradient or accent treatment on the selected row instead of flat opacity fill.
- [x] `SettingsScreen`: visual pass to match card style used elsewhere (rounded surface containers, icon-in-colored-circle treatment like `_FeatureRow` in `premium_screen.dart`, consistent spacing via `ZapTheme` constants).
- [x] Remove unused `lottie` dependency from `pubspec.yaml` if no use case surfaces during this pass (currently declared, never used — confirmed via grep).
- [x] Sweep `withOpacity(...)` deprecation warnings flagged by `flutter analyze` for any files touched in this phase, replacing with `withValues(alpha: ...)`.
- [x] Visual QA pass on a real device in both light and dark mode across all screens. (Verified on Android emulator: SoundPickerScreen gradient chips/rows + SettingsScreen icon-circles render correctly in both dark and light mode, no overflow.)

## Phase 4 — Release process & paid-feature testing

Carried over from prior plan (`/Users/nktushar/.claude/plans/plan-the-premium-subscription-indexed-goose.md`); auto-restore code already shipped.

- [x] Code: `PurchaseService.restoreSilently()` added, called fire-and-forget from `main.dart` on launch so reinstalls auto-unlock premium without a manual "Restore" tap.
- [x] Generate a release keystore and wire a real `signingConfig` in `android/app/build.gradle.kts`. (`android/app/zapsound-release.keystore` + `android/key.properties` generated, both gitignored; `build.gradle.kts` reads `key.properties` and signs release builds with it, falling back to the debug key if the file is absent. `flutter build appbundle` verified producing a signed `.aab` at `build/app/outputs/bundle/release/app-release.aab`.)
- [ ] Create the app in Google Play Console under applicationId `com.zapsound.zapsound_fresh`.
- [ ] Create an **Internal testing** release track; upload the `.aab` already built at `build/app/outputs/bundle/release/app-release.aab` (re-run `flutter build appbundle` for a fresh one before uploading).
- [ ] Create the in-app product `zapsound_premium_lifetime` (must match `PurchaseService.productId`) under Monetize → Products → In-app products, set price, activate.
- [ ] Add your Google account under Setup → License testing so test purchases don't charge real money.
- [ ] Install the internal-testing build, run a full test purchase, confirm premium unlocks.
- [ ] Uninstall/reinstall (or second device, same Google account) and confirm `restoreSilently()` auto-unlocks premium without visiting the paywall.
- [ ] Once Phases 1–3 are fully done and tested, proceed to production release (closed → open testing → production rollout per Play Console's standard review flow).

---

## How to use this file

Tell Claude Code to "execute Phase N" or a specific bullet. After each completed bullet, this file should be edited to flip `[ ]` → `[x]` before moving to the next one.
