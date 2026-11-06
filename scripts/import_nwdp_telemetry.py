#!/usr/bin/env python3
"""Resumable importer for public NWDP/CKAN CGWB groundwater telemetry resources.

The database-side function performs the HTTP fetch, field mapping, idempotent upsert,
and source-resource checkpoint update. This runner only schedules pages and commits
after each successful page so a cancelled run can safely resume.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-pages", type=int, default=1000,
                        help="Maximum successful 5,000-row pages for this run.")
    parser.add_argument("--page-size", type=int, default=5000,
                        help="Rows requested per page (database function caps this at 5,000).")
    parser.add_argument("--period", default="2021-2025",
                        help="Registered resource period to import.")
    return parser.parse_args()


def connect() -> psycopg2.extensions.connection:
    host = os.environ["SUPABASE_DB_HOST"]
    project_ref = os.environ["SUPABASE_PROJECT_REF"]
    password = os.environ["SUPABASE_DB_PASSWORD"]
    if not host or not project_ref or not password:
        raise RuntimeError("Missing Supabase database connection secrets.")
    return psycopg2.connect(
        host=host,
        port=5432,
        dbname="postgres",
        user=f"postgres.{project_ref}",
        password=password,
        sslmode="require",
        connect_timeout=30,
        application_name="samanvay-nwdp-import",
        keepalives=1,
        keepalives_idle=30,
        keepalives_interval=10,
        keepalives_count=5,
    )


def main() -> int:
    args = parse_args()
    if args.max_pages < 1 or args.page_size < 1 or args.page_size > 5000:
        raise SystemExit("--max-pages must be positive and --page-size must be 1..5000.")

    conn = connect()
    conn.autocommit = False
    pages_done = 0
    rows_done = 0
    failures: list[dict[str, str]] = []

    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                select source_resource_id, dataset_title, state_name,
                       coalesce(next_offset, 0) as next_offset
                from public.groundwater_source_resources
                where period_label = %s
                  and import_status <> 'completed'
                order by state_name nulls last, dataset_title, source_resource_id
                """,
                (args.period,),
            )
            resources = cur.fetchall()

        print(
            json.dumps({
                "period": args.period,
                "resources_pending_at_start": len(resources),
                "page_size": args.page_size,
                "max_pages": args.max_pages,
            }),
            flush=True,
        )

        for resource in resources:
            if pages_done >= args.max_pages:
                break

            resource_id = resource["source_resource_id"]
            resource_name = resource["dataset_title"]
            state_name = resource["state_name"]
            offset = int(resource["next_offset"] or 0)

            while pages_done < args.max_pages:
                result: Any = None
                last_error: Exception | None = None

                for attempt in range(1, 4):
                    try:
                        with conn.cursor() as cur:
                            cur.execute(
                                "select public.import_nwdp_telemetry_page(%s, %s, %s)",
                                (resource_id, offset, args.page_size),
                            )
                            result = cur.fetchone()[0]
                        conn.commit()
                        last_error = None
                        break
                    except Exception as exc:  # noqa: BLE001 - report the source failure.
                        conn.rollback()
                        last_error = exc
                        if attempt < 3:
                            time.sleep(attempt * 3)

                if last_error is not None:
                    failures.append({
                        "resource_id": resource_id,
                        "state": state_name or "",
                        "error": str(last_error)[:1000],
                    })
                    print(json.dumps({
                        "event": "resource_error",
                        "resource_id": resource_id,
                        "state": state_name,
                        "error": str(last_error)[:1000],
                    }), flush=True)
                    break

                if isinstance(result, str):
                    result = json.loads(result)
                page_rows = int(result.get("page_rows", 0))
                pages_done += 1
                rows_done += page_rows
                offset += page_rows

                print(json.dumps({
                    "event": "page_imported",
                    "state": state_name,
                    "resource": resource_name,
                    **result,
                    "pages_done_this_run": pages_done,
                }, default=str), flush=True)

                if result.get("complete") or page_rows == 0:
                    break

        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                select
                  count(*)::bigint as observation_rows,
                  count(distinct state_name)::int as states_with_observations,
                  count(distinct source_resource_id)::int as resources_with_observations
                from public.groundwater_station_observations
                """
            )
            totals = dict(cur.fetchone())
            cur.execute(
                """
                select
                  count(*)::int as catalogued_resources,
                  count(*) filter (where import_status = 'completed')::int as completed_resources,
                  count(*) filter (where import_status <> 'completed')::int as pending_resources,
                  coalesce(sum(source_record_count), 0)::bigint as known_source_rows,
                  coalesce(sum(imported_rows), 0)::bigint as imported_source_rows
                from public.groundwater_source_resources
                where period_label = %s
                """,
                (args.period,),
            )
            resource_totals = dict(cur.fetchone())

        print(json.dumps({
            "run_summary": {
                "pages_imported": pages_done,
                "rows_imported_this_run": rows_done,
                "observation_totals": totals,
                "resource_totals": resource_totals,
                "failures": failures,
            }
        }, default=str), flush=True)

        return 2 if failures else 0
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"Importer failed: {exc}", file=sys.stderr, flush=True)
        sys.exit(1)
