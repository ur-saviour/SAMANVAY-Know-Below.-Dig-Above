#!/usr/bin/env python3
"""Sync verified official State/UT building-approval service entrypoints.

This records portal discovery only. It never imports or fabricates approval records.
"""
from __future__ import annotations

import os
import psycopg2

PORTALS = [
    ("Arunachal Pradesh", "https://obps.arunachal.gov.in",
     "official_obps_portal_identified_authority_records_pending",
     "NIC confirms the Government of Arunachal Pradesh launched its Online Building Permission System. Portal mapping only; no approval records imported."),
    ("Chandigarh", "https://estateoffice.chd.gov.in/",
     "official_estate_office_building_plan_service_identified_records_pending",
     "Chandigarh Administration Estate Office e-Services lists Building Plan Approval (Apply Online). Public service entrypoint; approval records not imported."),
    ("Himachal Pradesh", "https://obpsud.hp.gov.in/index",
     "official_obps_portal_identified_authority_records_pending",
     "Government of Himachal Pradesh Urban Development Department e-Avedan building planning permission portal. Approval records not imported."),
    ("Lakshadweep", "https://serviceonline.gov.in/getServiceDesc.html?serviceId=21970002",
     "official_building_permit_service_directory_identified_records_pending",
     "National ServicePlus listing identifies Building Permit as a Lakshadweep PWD regulatory service with online submission. Service directory entrypoint only; no bulk register."),
    ("Manipur", "https://www.eodbmanipur.mn.gov.in/Services",
     "official_eodb_building_plan_service_identified_records_pending",
     "Manipur EODB service directory lists building-plan approval and revision services under MAHUD/concerned ULBs. Approval records not imported."),
    ("Meghalaya", "https://obps.meghalaya.gov.in/obps/aboutus.htm",
     "official_obps_portal_identified_authority_records_pending",
     "Meghalaya Urban Development Authority official OBPS portal; applications and permits are processed online. No public bulk approval export imported."),
    ("Puducherry", "https://ppa.py.gov.in/obps",
     "official_obps_portal_identified_authority_records_pending",
     "Puducherry Planning Authority official OBPS page. Authority portal mapped; no approval records imported."),
    ("Uttarakhand", "https://www.serviceonline.gov.in/uttarakhand/",
     "official_building_construction_noc_service_identified_records_pending",
     "Uttarakhand Urban Development ServicePlus directory lists NOC for building construction. Service entrypoint only; statewide building plan register export not verified."),
]

STATUS_ONLY = [
    ("Mizoram", "official_building_approval_system_confirmed_direct_portal_pending",
     "Mizoram Government sources confirm Aizawl Municipal Corporation launched OBPAS 2.0 for AMC jurisdiction. Direct operational portal endpoint and statewide/other ULB coverage were not independently verified; no approval records imported.",
     "https://dipr.mizoram.gov.in/post/speech-of-gen-dr-vijay-kumar-singh-pvsm-avsm-ysm-retd-honble-governor-of-mizoram-on-the-occasion-of-the-77th-republic-day-of-india-at-lammual-ground-aizawl1769417004"),
    ("Nagaland", "official_obps_implementation_in_progress",
     "Nagaland DIPR reported on 7 August 2026 that OBPS establishment, testing and rollout preparation were underway. No live production endpoint or approval records verified.",
     "https://ipr.nagaland.gov.in/node/21663"),
    ("Tripura", "official_urban_department_process_documented_direct_portal_pending",
     "Tripura Urban Development Department publishes Construction Permit Approval process and service timelines for municipal building plan approvals; direct public application portal and bulk records export remain unverified.",
     "https://udd.tripura.gov.in/sites/default/files/2024-01/Construction%20Permit%20Approval_1.pdf"),
]


def connect():
    return psycopg2.connect(
        host=os.environ["SUPABASE_DB_HOST"],
        port=5432,
        dbname="postgres",
        user=f"postgres.{os.environ['SUPABASE_PROJECT_REF']}",
        password=os.environ["SUPABASE_DB_PASSWORD"],
        sslmode="require",
        connect_timeout=30,
        application_name="samanvay-building-portal-sync",
    )


def main() -> int:
    conn = connect()
    try:
        with conn:
            with conn.cursor() as cur:
                updated = 0
                for state, url, status, notes in PORTALS:
                    cur.execute(
                        """
                        update public.india_data_coverage c
                        set official_portal_url=%s, coverage_status=%s,
                            notes=%s, last_checked_at=now()
                        from public.india_state_uts s
                        where s.name=%s and c.state_ut_id=s.id
                          and c.data_domain='building_approvals'
                        """,
                        (url, status, notes, state),
                    )
                    updated += cur.rowcount
                for state, status, notes, source_url in STATUS_ONLY:
                    cur.execute(
                        """
                        update public.india_data_coverage c
                        set official_portal_url=null, coverage_status=%s,
                            notes=%s, national_source_url=%s, last_checked_at=now()
                        from public.india_state_uts s
                        where s.name=%s and c.state_ut_id=s.id
                          and c.data_domain='building_approvals'
                        """,
                        (status, notes, source_url, state),
                    )
                    updated += cur.rowcount
                cur.execute(
                    """
                    select count(*) filter (where official_portal_url is not null),
                           count(*) filter (where official_portal_url is null),
                           count(*)
                    from public.india_data_coverage
                    where data_domain='building_approvals'
                    """
                )
                mapped, pending, total = cur.fetchone()
        print({
            "coverage_rows_updated": updated,
            "jurisdictions_with_portal_or_service_entrypoint": mapped,
            "direct_portal_mapping_pending": pending,
            "jurisdictions_total": total,
            "approval_records_imported": 0,
            "note": "Portal discovery is not an approval-register import."
        }, flush=True)
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
