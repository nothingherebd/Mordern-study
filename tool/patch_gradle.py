#!/usr/bin/env python3
"""
Robustly patches the freshly-scaffolded Android Gradle files to use a
modern Kotlin version and compileSdk 35 (required by audioplayers_android).

Handles both the modern plugins{} block style (settings.gradle) and the
legacy ext.kotlin_version style (root build.gradle), and both `key value`
and `key = value` Groovy syntax, since Flutter's scaffold template has
changed this formatting across versions. Every patch prints whether it
actually matched, so failures are visible in the CI log instead of silent.
"""
import os
import re
import sys

SETTINGS = "android/settings.gradle"
ROOT_BUILD = "android/build.gradle"
APP_BUILD = "android/app/build.gradle"

KOTLIN_VERSION = "1.9.24"
COMPILE_SDK = "35"


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


def patch_app_build_gradle():
    _patch_file(
        APP_BUILD,
        [(
            r'compileSdk(Version)?\s*=?\s*flutter\.compileSdkVersion',
            f'compileSdk = {COMPILE_SDK}',
        ), (
            r'compileSdk(Version)?\s*=?\s*\d+',
            f'compileSdk = {COMPILE_SDK}',
        )],
        "app/build.gradle (compileSdk)",
    )


if __name__ == "__main__":
    try:
        patch_settings_gradle()
        patch_root_build_gradle()
        patch_app_build_gradle()
    except Exception as e:
        print(f"[patch_gradle] ERROR: {e}", file=sys.stderr)
        sys.exit(1)
