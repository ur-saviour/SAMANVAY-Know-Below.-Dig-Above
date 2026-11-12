#!/usr/bin/env python3
"""Static regression checks for SAMANVAY's safety-critical demo contracts.

These checks do not replace Flutter widget tests, Supabase role-session tests,
or physical-device acceptance. They guard a small set of source-level promises
that must remain true in every Android and browser build.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
MAIN = APP / "main.dart"
errors: list[str] = []
passed: list[str] = []

def check(condition: bool, message: str) -> None:
    if condition:
        passed.append(message)
    else:
        errors.append(message)

def source(path: Path) -> str:
    if not path.is_file():
        errors.append(f"Required source file missing: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")

main = source(MAIN)

# Role labels and profile-preview isolation.
check("'requester' => 'Citizen'" in main,
      "Internal requester role is presented as Citizen.")
for label in ("Citizen", "Department Officer", "Coordinator", "Administrator"):
    check(f"'title': '{label}'" in main,
          f"Profile switcher includes {label}.")
check("Demo role switching does not alter your authenticated account or production permissions." in main,
      "Profile switcher explicitly disclaims production permission changes.")
check("They do not authenticate with Supabase, impersonate users, or grant access to protected records." in main,
      "Staff preview is explicitly read-only and non-impersonating.")
check("PUBLIC-ADMIN-DEMO" in main and "PUBLIC-COORDINATOR-DEMO" in main
      and "PUBLIC-OFFICER-DEMO" in main and "PUBLIC-CITIZEN-DEMO" in main,
      "All four demo workspaces use separate public demo identifiers.")

# Guard visible copy against the deprecated role label.
visible_role_pattern = re.compile(
    r"""(?:Text|title|label|tooltip|semanticsLabel)\s*\(?\s*['"]Requester['"]""",
    re.IGNORECASE,
)
visible_role_hits = []
for dart_file in APP.glob("*.dart"):
    text = dart_file.read_text(encoding="utf-8")
    if visible_role_pattern.search(text):
        visible_role_hits.append(dart_file.name)
check(not visible_role_hits,
      "No visible UI label uses the deprecated Requester wording."
      + (f" Found in: {', '.join(visible_role_hits)}" if visible_role_hits else ""))

# GIS disclosure and conservative handling of utility data.
check("'get_underground_asset_overview'" in main,
      "GIS requests use the authenticated aggregate overview RPC.")
check("generalised 250 m aggregate cells, never exact utility routes" in main,
      "Map source documents that public GIS is aggregated, not an exact utility route.")
check("Generalised 250 m density cells can be extruded" in main
      and "never physical depth or a pipe route" in main,
      "3D density visualisation is not represented as physical depth or pipe geometry.")
check("an empty layer is not excavation clearance" in main.lower(),
      "UI warns that an empty utility layer is not proof of site clearance.")

# The public ward reference layer must be valid GeoJSON before either build.
ward_file = APP / "assets" / "reference" / "coimbatore" / "coimbatore_wards_2024_public_domain.geojson"
if ward_file.is_file():
    try:
        geo = json.loads(ward_file.read_text(encoding="utf-8"))
        features = geo.get("features") if isinstance(geo, dict) else None
        check(geo.get("type") == "FeatureCollection" and isinstance(features, list) and len(features) > 0,
              "Coimbatore ward layer parses as a non-empty GeoJSON FeatureCollection.")
        if isinstance(features, list) and features:
            check(all(isinstance(item, dict) and item.get("geometry") for item in features),
                  "Every ward feature has a geometry object.")
    except (json.JSONDecodeError, OSError) as exc:
        errors.append(f"Coimbatore ward GeoJSON is unreadable: {exc}")
else:
    check(False, "Coimbatore ward GeoJSON source asset exists.")

# Brand asset is required by both platform build pipelines.
logo = APP / "assets" / "brand" / "samanvay_logo.svg"
if logo.is_file():
    svg = logo.read_text(encoding="utf-8")
    check("<svg" in svg and "</svg>" in svg,
          "SAMANVAY brand logo is a complete SVG document.")
else:
    check(False, "SAMANVAY SVG logo source asset exists.")

for message in passed:
    print(f"PASS: {message}")
for message in errors:
    print(f"FAIL: {message}", file=sys.stderr)

print(f"\nSAMANVAY contract checks: {len(passed)} passed, {len(errors)} failed.")
sys.exit(1 if errors else 0)
