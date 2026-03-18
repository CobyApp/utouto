# AlarmKit setup & troubleshooting (Utouto)

AlarmKit is used so alarms can ring at the set time (Lock Screen, Dynamic Island, system alarm UI). If the alarm does **not** ring when the time comes, check the following.

## 1. AlarmKit entitlement (required)

AlarmKit requires a **special entitlement** from Apple. Without it, the system may not actually fire alarms even if the user granted permission.

- **Tuist**: The app target uses `entitlements: .file(path: "Sources/Utouto/Utouto.entitlements")` in `Project.swift`. The file is under source control so any capability you add in Xcode (e.g. AlarmKit) will be kept after `tuist generate`.
- **AlarmKit**: The entitlement key for AlarmKit is **not** publicly documented and may require Apple to enable it for your App ID. If you see *"Entitlement com.apple.developer.alarmkit not found"*, remove that key from the entitlements file (it has been removed in this project). Then add **AlarmKit** in Xcode (**Signing & Capabilities** → **+ Capability** → **AlarmKit**) only when it appears in the list for your team. If it does not appear, **request access** via the [Apple Developer portal](https://developer.apple.com/). Until then, the app will build and install but alarms may not ring.

Until the entitlement is granted, alarms might schedule without error but **never ring**.

## 2. Info.plist (Tuist)

- **Main app**: `Sources/Utouto/Info.plist` — set `NSAlarmKitUsageDescription`, `NSSupportsLiveActivities`, permissions, Supabase keys, etc. Referenced in `Project.swift` as `infoPlist: .file(path: "Sources/Utouto/Info.plist")`.
- **Widget extension**: No separate file; extension Info is defined in `Project.swift` via `infoPlist: .dictionary([...])` for the `UtoutoWidgetExtension` target (NSExtension, widgetkit-extension, principal class).
- The app must call `AlarmManager.requestAuthorization()` and the user must grant permission (onboarding or first alarm).

## 3. App behavior in code

- **Re-schedule on load**: When the alarm list is loaded (including after app launch), all **enabled** alarms are re-registered with AlarmKit. This covers:
  - App restart
  - Device restart (AlarmKit may clear; we re-sync when the user opens the app and the list loads)
- **Schedule types**:
  - One-time with date: `.fixed(date)` (past dates are moved to the next day).
  - Once (no repeat, no date): next occurrence of (hour, minute) as `.fixed(next)`.
  - Weekly repeat: `.relative(time, repeats: .weekly(weekdays))` with `Locale.Weekday` (sun…sat).

## 4. Simulator vs device

- AlarmKit is intended for **physical devices** (iOS 26+). Alarms may not ring or may behave incorrectly in the **simulator**.
- Prefer testing on a **real device** to confirm that alarms fire at the set time.

## 5. Custom sound

- Custom alarm sounds are copied to `Library/Sounds/{alarmId}.m4a` and used via `AlertSound.named(fileName)`.
- If the copy fails, the app falls back to `.default`. If the alarm still does not ring, the cause is likely entitlement, permission, or device/simulator, not the sound file.

## 6. Live Activity & Widget extension (WWDC25 AlarmKit)

- **AlarmPresentation**: The app configures `AlarmPresentation(alert: countdown: paused:)` so that:
  - **Alert**: When the alarm fires (title, snooze button).
  - **Countdown**: Shown before the alarm or during snooze (title, pause button).
  - **Paused**: When the user pauses the countdown (title, resume button).
- **NSSupportsLiveActivities**: Set to `true` in the main app Info.plist.
- **UtoutoWidgetExtension**: A Widget extension implements `ActivityConfiguration(for: AlarmAttributes<UtoutoAlarmMetadata>.self)` so that:
  - Lock Screen shows a custom countdown/alert/paused view.
  - Dynamic Island shows compact and expanded regions (alarm icon, title, countdown).
- **UtoutoAlarmKit**: A shared static framework that provides `UtoutoAlarmMetadata` (AlarmMetadata) so both the app and the widget use the same type. The app and the widget extension depend on this target.

Reference: [AlarmKit API로 알람 맞추기 - WWDC25](https://developer.apple.com/kr/videos/play/wwdc2025/230/).

## Why nothing appears (no Live Activity, no alert, no sound)

If at the set time nothing happens (no banner, no sound, no Live Activity), work through the following.

1. **AlarmKit entitlement (most common)**  
   Without the **AlarmKit capability** from Apple, the system may accept your schedule but **never fire** the alarm.  
   - In Xcode: **Signing & Capabilities** → **+ Capability** → add **AlarmKit** (or request it from Apple Developer if not listed).  
   - Until this is granted, alarms can “save” in the app but will not ring or show any system UI.

2. **Permission**  
   **Settings → うとうと (Utouto) → Alarms** must be **ON**. If it’s off or not present, alarms won’t fire.

3. **Save-time error**  
   When saving an alarm, if registration with AlarmKit fails, the app shows an alert: “Alarm could not be registered”. If you see that, fix permission/entitlement and try again.

4. **Debug console**  
   In Xcode, run on a **real device** and watch the console when you save an alarm. You should see:  
   `[AlarmKit] Scheduled alarm id=... schedule=...`  
   If you see `AlarmKit schedule error:` instead, the failure reason is in the log.

5. **Real device**  
   Use a **physical iPhone (iOS 26+)**. Simulator may not run AlarmKit correctly.

6. **Re-sync after app/device restart**  
   Open the app, go to the **Alarms** tab, and wait for the list to load so that enabled alarms are re-registered with AlarmKit.

7. **Sound**  
   The app currently uses the **default system alarm sound** to avoid issues with custom files. After confirming that alarms fire, custom sounds can be re-enabled.

## Checklist when alarm does not ring

1. **Entitlement**: AlarmKit capability added and approved by Apple (if required).
2. **Permission**: Settings → Utouto → Alarms (or equivalent) is **ON**.
3. **Device**: Test on a **real device**, not simulator.
4. **Re-sync**: Open the app, go to the alarm list, and wait for the list to load (enabled alarms are re-scheduled to AlarmKit).
5. **Time**: For “once” alarms, the next occurrence of the set time is used; for one-time with date, past dates are moved to the next day.
