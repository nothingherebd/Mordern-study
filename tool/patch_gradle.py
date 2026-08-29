#!/usr/bin/env python3
"""
Robustly patches the freshly-scaffolded android/settings.gradle and
android/app/build.gradle to use a modern Kotlin plugin version and
compileSdk 35 (required by audioplayers_android).

Uses regex (not a plain sed one-liner) so it survives Flutter changing
quote style / whitespace in its scaffold template between versions, and
prints whether a change was actually made so a future failure is easy
to diagnose from the CI log instead of failing silently.
"""
import re
import sys

SETTINGS = "android/settings.gradle"
APP_BUILD = "android/app/build.gradle"

KOTLIN_VERSION = "1.9.24"
COMPILE_SDK = "35"


def patch_settings():
    with open(SETTINGS, "r", encoding="utf-8") as f:
        content = f.read()

    new_content = re.sub(
        r'id\s+[\'"]org\.jetbrains\.kotlin\.android[\'"]\s+version\s+[\'"][0-9.]+[\'"]',
        f'id "org.jetbrains.kotlin.android" version "{KOTLIN_VERSION}"',
        content,
    )

    if new_content != content:
        with open(SETTINGS, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"[patch_gradle] settings.gradle: Kotlin plugin version -> {KOTLIN_VERSION}")
    else:
        print("[patch_gradle] WARNING: settings.gradle Kotlin plugin line not found — no change made")


def patch_app_build():
    with open(APP_BUILD, "r", encoding="utf-8") as f:
        content = f.read()

    new_content = re.sub(
        r'compileSdk(Version)?\s+flutter\.compileSdkVersion',
        f'compileSdk {COMPILE_SDK}',
        content,
    )
    new_content = re.sub(
        r'compileSdk(Version)?\s+\d+',
        f'compileSdk {COMPILE_SDK}',
        new_content,
    )

    if new_content != content:
        with open(APP_BUILD, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"[patch_gradle] app/build.gradle: compileSdk -> {COMPILE_SDK}")
    else:
        print("[patch_gradle] WARNING: app/build.gradle compileSdk line not found — no change made")


if __name__ == "__main__":
    try:
        patch_settings()
        patch_app_build()
    except FileNotFoundError as e:
        print(f"[patch_gradle] Could not find {e.filename} — did the Android scaffold step run first?", file=sys.stderr)
        sys.exit(1)
