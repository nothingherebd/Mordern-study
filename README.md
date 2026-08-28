# BCS Prep Planner (Flutter)

Native Android study planner with **real exact alarms** — scheduled through
`flutter_local_notifications` + the `timezone` package, so they fire even if
the app is closed or the phone reboots. This replaces the earlier PWA version,
which could only notify while a browser tab stayed open.

## What's included
- **Plan tab** — day-by-day task list, opens on tomorrow by default; add a
  task with a start/end time, a subject tag, and an optional start-time reminder.
- **Subjects tab** — color-tagged subjects with an optional daily time slot
  and repeat days; toggle "fire a notification 1 minute before start".
- **Alarms tab** — classic repeating alarms (time + label + days), on/off
  switch, and a "send test notification now" button for quick debugging.
- Storage via **Hive** (local, on-device, no server).

## Why there's no `android/` folder in this repo
The native Android project (Gradle files, wrapper, manifest) is generated
fresh by the real `flutter create` command inside GitHub Actions — that's far
more reliable than hand-written Gradle boilerplate. A small script,
`tool/patch_manifest.py`, then injects the permissions and receivers
`flutter_local_notifications` needs for exact/repeating/boot-surviving alarms.

## Build via GitHub Actions (recommended)
1. Create a new GitHub repo and push everything in this folder to it.
2. Push to `main` (or run the workflow manually from the **Actions** tab —
   it's also set up with `workflow_dispatch`).
3. Open the finished run → **Artifacts** → download `bcs-planner-apk`.
4. Transfer the `.apk` to your phone and install it (you'll need to allow
   "install unknown apps" for whatever app you use to open it).

## Building locally instead
```bash
flutter create --platforms=android --org com.bcsplanner .
python3 tool/patch_manifest.py
flutter pub get
flutter build apk --release
# APK lands in build/app/outputs/flutter-apk/app-release.apk
```

## First launch on your phone
- Grant the notification permission prompt.
- Grant the "Allow exact alarms" prompt (Android 12+) — without it, alarms
  fall back to inexact timing and can drift by several minutes.
- Some phone brands (Xiaomi/MIUI, Oppo/ColorOS, Vivo, Samsung's aggressive
  battery saver) kill background apps by default — if alarms stop firing
  after a while, allow "autostart" / disable battery optimization for this
  app in your phone's settings.

## Known limitation
The "1 minute before" subject reminder computes the time by simple
arithmetic; a subject scheduled to start at exactly `00:00` will not roll
back correctly to `23:59` the previous day. Pick any start time after
`00:00` and this doesn't come up in practice.
