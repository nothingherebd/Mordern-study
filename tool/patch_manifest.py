#!/usr/bin/env python3
"""
Patches android/app/src/main/AndroidManifest.xml (generated fresh by
`flutter create`) with the permissions and receivers flutter_local_notifications
needs for exact, repeating alarms that survive app close and device reboot.

Run after `flutter create` has produced the android/ folder and before
`flutter build apk`.
"""
import re
import sys

PATH = "android/app/src/main/AndroidManifest.xml"

PERMISSIONS = """
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
"""

RECEIVERS = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

def main():
    with open(PATH, "r", encoding="utf-8") as f:
        xml = f.read()

    if "SCHEDULE_EXACT_ALARM" not in xml:
        # Insert permissions right after the opening <manifest ...> tag.
        xml = re.sub(
            r"(<manifest[^>]*>)",
            r"\1" + PERMISSIONS,
            xml,
            count=1,
        )

    if "ScheduledNotificationReceiver" not in xml:
        # Insert receivers just before </application>.
        xml = xml.replace("</application>", RECEIVERS + "    </application>")

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(xml)

    print("AndroidManifest.xml patched successfully.")

if __name__ == "__main__":
    try:
        main()
    except FileNotFoundError:
        print(f"Could not find {PATH} — did `flutter create` run first?", file=sys.stderr)
        sys.exit(1)
