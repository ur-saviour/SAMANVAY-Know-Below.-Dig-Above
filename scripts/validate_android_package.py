#!/usr/bin/env python3
"""Validate generated Android manifest, launcher assets and package identity."""
from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
gradle_kts = ROOT / "android/app/build.gradle.kts"
gradle_groovy = ROOT / "android/app/build.gradle"
errors: list[str] = []
passed: list[str] = []

def check(condition: bool, message: str) -> None:
    (passed if condition else errors).append(message)

if not manifest.is_file():
    errors.append("Generated AndroidManifest.xml is missing.")
else:
    try:
        tree = ET.parse(manifest)
        root = tree.getroot()
        android = "{http://schemas.android.com/apk/res/android}"
        app = root.find("application")
        check(app is not None, "Manifest contains an application element.")
        check(app is not None and app.get(android + "label") == "SAMANVAY",
              "Launcher application label is SAMANVAY.")
        permissions = {node.get(android + "name") for node in root.findall("uses-permission")}
        for permission in (
            "android.permission.INTERNET",
            "android.permission.ACCESS_FINE_LOCATION",
            "android.permission.ACCESS_COARSE_LOCATION",
        ):
            check(permission in permissions, f"Manifest declares {permission}.")
        deep_link = any(
            data.get(android + "scheme") == "in.samanvay"
            and data.get(android + "host") == "login-callback"
            for data in root.findall(".//data")
        )
        check(deep_link, "Manifest declares the Supabase login callback deep link.")
    except ET.ParseError as exc:
        errors.append(f"Generated Android manifest is invalid XML: {exc}")

gradle = gradle_kts if gradle_kts.is_file() else gradle_groovy
if not gradle.is_file():
    errors.append("Generated Android app Gradle file is missing.")
else:
    text = gradle.read_text(encoding="utf-8")
    for key in ("namespace", "applicationId"):
        check(bool(re.search(
            rf"{key}\s*(?:=\s*)?['\"]org\.samanvay\.samanvay['\"]",
            text,
        )), f"Android {key} is org.samanvay.samanvay.")

resources = ROOT / "android/app/src/main/res"
for density in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
    icon = resources / f"mipmap-{density}/ic_launcher.png"
    check(icon.is_file() and icon.stat().st_size > 0,
          f"Generated {density} launcher icon exists and is non-empty.")
for asset in (
    resources / "drawable/ic_launcher_foreground.png",
    resources / "mipmap-anydpi-v26/ic_launcher.xml",
    resources / "mipmap-anydpi-v26/ic_launcher_round.xml",
    resources / "values/ic_launcher_background.xml",
):
    check(asset.is_file() and asset.stat().st_size > 0,
          f"Generated adaptive launcher resource exists: {asset.relative_to(ROOT)}")

for message in passed:
    print(f"PASS: {message}")
for message in errors:
    print(f"FAIL: {message}", file=sys.stderr)
print(f"\nAndroid package contract: {len(passed)} passed, {len(errors)} failed.")
sys.exit(1 if errors else 0)
