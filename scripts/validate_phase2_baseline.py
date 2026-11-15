#!/usr/bin/env python3
"""Read-only checks for SAMANVAY Phase 2 build/environment assumptions.

This is a repository contract check, not a Flutter build or runtime test.
It intentionally does not access Supabase or require credentials.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / ".github/workflows/build-apk.yml"
WEB = ROOT / ".github/workflows/build-web.yml"
errors: list[str] = []
passed: list[str] = []
notes: list[str] = []


def check(condition: bool, message: str) -> None:
    (passed if condition else errors).append(message)


def read(path: Path) -> str:
    if not path.is_file():
        errors.append(f"Missing required file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


android = read(ANDROID)
web = read(WEB)

# Both release targets must use the same pinned Flutter SDK.
versions = []
for label, content in (("Android", android), ("Web", web)):
    match = re.search(r"flutter-version:\\s*['\\"]([^'\\"]+)['\\"]", content)
    check(match is not None, f"{label} workflow declares a Flutter SDK version.")
    if match:
        versions.append((label, match.group(1)))
check(len(versions) == 2 and versions[0][1] == versions[1][1],
      "Android and Web workflows use the same Flutter SDK version.")

for label, content, platform in (
    ("Android", android, "android"), ("Web", web, "web")
):
    check(f"--platforms {platform}" in content,
          f"{label} workflow scaffolds the expected Flutter platform.")
    check("cp /tmp/" in content and "pubspec.yaml ." in content,
          f"{label} workflow currently generates and copies a temporary pubspec.")
    check("flutter pub get" in content,
          f"{label} workflow resolves dependencies before compiling.")

# Critical shared package versions must not drift between platform pipelines.
for package in ("supabase_flutter", "maplibre_gl", "crypto"):
    found = {}
    for label, content in (("Android", android), ("Web", web)):
        match = re.search(rf"flutter pub add {re.escape(package)}:([A-Za-z0-9.+-]+)", content)
        found[label] = match.group(1) if match else None
    check(found["Android"] is not None and found["Android"] == found["Web"],
          f"{package} is explicitly version-pinned identically in Android and Web workflows.")

check("secrets.SUPABASE_URL" in web and "secrets.SUPABASE_PUBLISHABLE_KEY" in web,
      "Web build reads Supabase public configuration from GitHub Actions secrets.")
check("--dart-define=SUPABASE_URL" in web and "--dart-define=SUPABASE_PUBLISHABLE_KEY" in web,
      "Web build passes Supabase configuration as compile-time defines.")
check("secrets.MAPTILER_API_KEY" in web and "--dart-define=MAPTILER_API_KEY" in web,
      "Web map key is injected from a GitHub Actions secret.")

contract_script = ROOT / "scripts/validate_samanvay_contracts.py"
check(contract_script.is_file(), "Existing SAMANVAY source-contract validator is present.")
notes.append("No root pubspec.yaml/pubspec.lock is committed; local builds still depend on CI-generated scaffolding.")
notes.append("No isolated Supabase staging database is provisioned by this check.")
notes.append("This script does not execute Flutter, migrations, authenticated API tests, or device tests.")

for item in passed:
    print(f"PASS: {item}")
for item in notes:
    print(f"GAP: {item}")
for item in errors:
    print(f"FAIL: {item}", file=sys.stderr)
print(f"\\nPhase 2 baseline: {len(passed)} passed, {len(errors)} failed, {len(notes)} known gaps.")
sys.exit(1 if errors else 0)
