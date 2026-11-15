#!/usr/bin/env python3
"""Read-only provenance checks for the SAMANVAY SQL migration set.

This is a static inventory, not a SQL parser and not a migration executor.
It deliberately refuses to manufacture missing baseline schema.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
TIMESTAMPED = re.compile(r"^(\d{14})_[a-z0-9_]+\.sql$")
CREATE_TABLE = re.compile(
    r"\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?"
    r"([a-z_][\w]*)\.([a-z_][\w]*)",
    re.IGNORECASE,
)
PUBLIC_REFERENCE = re.compile(
    r"\b(?:references|on|from|join|update|into)\s+"
    r"public\.([a-z_][\w]*)",
    re.IGNORECASE,
)

def main() -> int:
    if not MIGRATIONS.is_dir():
        print("FAIL: supabase/migrations directory is missing.")
        return 1

    files = sorted(p for p in MIGRATIONS.glob("*.sql") if p.is_file())
    if not files:
        print("FAIL: no SQL migration files found.")
        return 1

    malformed = [p.name for p in files if not TIMESTAMPED.match(p.name)]
    print(f"Migration files discovered: {len(files)}")
    print(f"Timestamp naming violations: {len(malformed)}")
    for name in malformed:
        print(f"  - {name}")

    created: set[str] = set()
    referenced: set[str] = set()
    first_sql = ""
    for index, path in enumerate(files):
        sql = path.read_text(encoding="utf-8")
        if index == 0:
            first_sql = sql
        created.update(f"{schema}.{table}" for schema, table in CREATE_TABLE.findall(sql))
        referenced.update(f"public.{table}" for table in PUBLIC_REFERENCE.findall(sql))

    unresolved = sorted(ref for ref in referenced if ref not in created)
    print(f"Tables created by this migration set: {len(created)}")
    print(f"Referenced public tables not created in this set: {len(unresolved)}")
    for name in unresolved:
        print(f"  - {name}")

    config = ROOT / "supabase" / "config.toml"
    print(f"Supabase CLI config present: {'yes' if config.is_file() else 'no'}")
    print(f"Foundational public tables created in migration set:")
    for table in ("profiles", "departments", "excavation_requests"):
        print(f"  - public.{table}: {'yes' if f'public.{table}' in created else 'no'}")

    if first_sql:
        print(f"First migration: {files[0].name}")
        print("First migration begins with:")
        for line in first_sql.splitlines()[:8]:
            print(f"  {line}")

    blockers = []
    for table in ("profiles", "departments", "excavation_requests"):
        if f"public.{table}" not in created:
            blockers.append(f"public.{table} has no CREATE TABLE in the checked-in migration set")
    if not config.is_file():
        blockers.append("supabase/config.toml is absent; local Supabase project configuration is not reproducible from this tree")

    if malformed:
        blockers.append("one or more migration filenames do not follow the 14-digit timestamp convention")

    print()
    if blockers:
        print("RESULT: BASELINE PROVENANCE INCOMPLETE")
        for blocker in blockers:
            print(f"BLOCKER: {blocker}")
        print("SAFE NEXT STEP: obtain an owner-approved, sanitised schema-only baseline or authoritative original bootstrap migrations.")
        print("DO NOT replay this migration set against blank Postgres and treat missing-object errors as migration defects.")
        return 0

    print("RESULT: static prerequisite checks did not identify the known foundational-table/config blockers.")
    print("This does not establish that migrations replay successfully or that the database is runtime-correct.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
