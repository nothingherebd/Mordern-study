#!/usr/bin/env python3
"""
Patches the freshly-scaffolded Android Gradle files to use a modern
Kotlin version, matching what flutter_local_notifications / flutter_timezone
require. Handles both the modern plugins{} block style (settings.gradle)
and the legacy ext.kotlin_version style (root build.gradle), since
Flutter's scaffold template format has changed across versions.
"""
import os
import re
import sys

SETTINGS = "android/settings.gradle"
ROOT_BUILD = "android/build.gradle"

KOTLIN_VERSION = "1.9.24"


def _patch_file(path, patterns_and_replacements, label):
    if not os.path.exists(path):
        print(f"[patch_gradle] {label}: {path} does not exist — skipping")
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    original = content
    for pattern, replacement in patterns_and_replacements:
        content = re.sub(pattern, replacement, content)
    if content != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"[patch_gradle] {label}: patched")
    else:
        print(f"[patch_gradle] {label}: WARNING — no matching pattern found, no change made")


def patch_settings_gradle():
    _patch_file(
        SETTINGS,
        [(
            r'id\s+[\'"]org\.jetbrains\.kotlin\.android[\'"]\s+version\s+[\'"][0-9.]+[\'"]',
            f'id "org.jetbrains.kotlin.android" version "{KOTLIN_VERSION}"',
        )],
        "settings.gradle (plugins block Kotlin version)",
    )


def patch_root_build_gradle():
    _patch_file(
        ROOT_BUILD,
        [(
            r'ext\.kotlin_version\s*=\s*[\'"][0-9.]+[\'"]',
            f"ext.kotlin_version = '{KOTLIN_VERSION}'",
        ), (
            r'org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9.]+',
            f'org.jetbrains.kotlin:kotlin-gradle-plugin:{KOTLIN_VERSION}',
        )],
        "android/build.gradle (ext.kotlin_version / classpath)",
    )


if __name__ == "__main__":
    try:
        patch_settings_gradle()
        patch_root_build_gradle()
    except Exception as e:
        print(f"[patch_gradle] ERROR: {e}", file=sys.stderr)
        sys.exit(1)
