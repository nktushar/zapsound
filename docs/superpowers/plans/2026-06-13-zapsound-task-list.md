# ZapSound Task List

Full plan: [2026-06-13-zapsound-review-plan.md](./2026-06-13-zapsound-review-plan.md)

## Part 1: Background charger reliability
- [ ] 1.1 Self-healing service restart in ZapReceiver.kt
- [ ] 1.2 Battery-exemption MethodChannel in MainActivity.kt
- [ ] 1.3 Settings "Background & Reliability" section
- [ ] 1.4 Manual e2e verify + commit

## Part 2: Premium preview
- [x] 2.1 Allow preview for locked sounds + commit

## Part 3: Voice recording
- [x] 3.1 Add record/path_provider deps
- [x] 3.2 RecordingService
- [x] 3.3 RecordSoundScreen
- [x] 3.4 Wire "My Recording" into picker
- [x] 3.5 iOS mic permission string
- [x] 3.6 Manual test + commit

## Part 4: App icon
- [ ] 4.1 Generate icon images
- [ ] 4.2 Configure flutter_launcher_icons
- [ ] 4.3 Verify + commit

## Part 5: Play Store deployment
- [ ] 5.1 Create upload keystore
- [ ] 5.2 Wire release signing config
- [ ] 5.3 Versioning convention
- [ ] 5.4 Play Console setup checklist

## Final
- [ ] Update CLAUDE.md + commit
