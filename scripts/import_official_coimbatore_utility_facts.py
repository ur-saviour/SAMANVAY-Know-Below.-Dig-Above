#!/usr/bin/env python3
"""Import official Coimbatore municipal utility project facts and approval-search audit.

Only aggregate/project-level facts are stored here. No underground pipe alignments,
coordinates, depths, manhole positions, exact utility routes, applicant details or
residential plot addresses are imported.
"""
from __future__ import annotations

import json
import os
import psycopg2
from psycopg2.extras import execute_values


def connect():
    required = ("SUPABASE_DB_HOST", "SUPABASE_PROJECT_REF", "SUPABASE_DB_PASSWORD")
    missing = [name for name in required if not os.getenv(name)]
    if missing:
        raise RuntimeError("Missing database secrets: " + ", ".join(missing))
    return psycopg2.connect(
        host=os.environ["SUPABASE_DB_HOST"],
        port=5432,
        dbname="postgres",
        user=f"postgres.{os.environ['SUPABASE_PROJECT_REF']}",
        password=os.environ["SUPABASE_DB_PASSWORD"],
        sslmode="require",
        connect_timeout=30,
        application_name="samanvay-official-utility-facts",
    )


DDL = """
create table if not exists public.infrastructure_project_facts (
    id uuid primary key default gen_random_uuid(),
    project_key text not null,
    project_name text not null,
    issuing_authority text not null,
    asset_domain text not null,
    geography text not null,
    coverage_areas text,
    metric_key text not null,
    metric_label text not null,
    metric_value numeric not null,
    metric_unit text not null,
    reported_reference_year integer,
    source_key text not null,
    source_url text not null,
    source_title text not null,
    source_reference text not null,
    verification_status text not null,
    operational_use_allowed boolean not null default false,
    geometry_available boolean not null default false,
    notes text not null default '',
    last_verified_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (project_key, metric_key, source_key)
);

create index if not exists infrastructure_project_facts_geography_idx
    on public.infrastructure_project_facts (geography, asset_domain);
create index if not exists infrastructure_project_facts_domain_idx
    on public.infrastructure_project_facts (asset_domain, project_key);

alter table public.infrastructure_project_facts enable row level security;
drop policy if exists "Authenticated users can read official project facts"
    on public.infrastructure_project_facts;
create policy "Authenticated users can read official project facts"
    on public.infrastructure_project_facts for select to authenticated
    using (true);
drop policy if exists "Admins and coordinators manage official project facts"
    on public.infrastructure_project_facts;
create policy "Admins and coordinators manage official project facts"
    on public.infrastructure_project_facts for all to authenticated
    using (exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role in ('admin','coordinator')
    ))
    with check (exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role in ('admin','coordinator')
    ));
grant select, insert, update, delete on public.infrastructure_project_facts to authenticated;

create table if not exists public.building_approval_search_audits (
    id uuid primary key default gen_random_uuid(),
    query_fingerprint text not null unique,
    issuing_authority text not null,
    ulb_name text not null,
    portal_url text not null,
    request_type text,
    approval_from_date date,
    approval_to_date date,
    status_filter text not null,
    result_count integer not null,
    result_status text not null,
    observed_result_fields text[] not null default '{}',
    personal_data_collected boolean not null default false,
    notes text not null default '',
    queried_at timestamptz not null default now()
);

alter table public.building_approval_search_audits enable row level security;
drop policy if exists "Authenticated users can read approval search audits"
    on public.building_approval_search_audits;
create policy "Authenticated users can read approval search audits"
    on public.building_approval_search_audits for select to authenticated
    using (true);
drop policy if exists "Admins and coordinators manage approval search audits"
    on public.building_approval_search_audits;
create policy "Admins and coordinators manage approval search audits"
    on public.building_approval_search_audits for all to authenticated
    using (exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role in ('admin','coordinator')
    ))
    with check (exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role in ('admin','coordinator')
    ));
grant select, insert, update, delete on public.building_approval_search_audits to authenticated;
"""


SOURCES = [
    ("ccmc_water_supply", "Coimbatore City Municipal Corporation",
     "Water Supply Department — source schemes and distribution responsibilities",
     "https://www.ccmc.gov.in/index.php/department/water-supply", "Coimbatore, Tamil Nadu",
     "water_supply", "public_web", "official_page_registered", "HTML",
     "Official CCMC Water Supply department page. It documents Siruvani and Pillur as major supply sources and the municipal distribution role. It does not publish a public surveyed pipe GIS export."),
    ("ccmc_ugd", "Coimbatore City Municipal Corporation",
     "UGD / Stormwater Drainage Department — public coverage summary",
     "https://www.ccmc.gov.in/index.php/department/ugd", "Coimbatore, Tamil Nadu",
     "sewerage_stormwater", "public_web", "official_page_registered", "HTML",
     "Official CCMC page reports 603.50 km stormwater drains and about 40 km of new drains being added annually. Project-area references include Kurichi/Kuniyamuthur and four added areas. No surveyed line geometry is published on this page."),
    ("ccmc_citizens_charter", "Coimbatore City Municipal Corporation",
     "Citizens Charter — historical water supply service baseline",
     "https://www.ccmc.gov.in/img/upload/CitizensCharterEnglish1.pdf", "Coimbatore, Tamil Nadu",
     "water_supply", "public_document", "official_historical_document", "PDF",
     "Archived CCMC Citizen Charter references 2,380 km of distribution network and 126 storage reservoirs using a 2011 population context. The extracted document view does not state a current survey date; values are stored only as historical context, not as current asset counts."),
    ("ccmc_budget_2023_24", "Coimbatore City Municipal Corporation",
     "Coimbatore Corporation Budget 2023-24 — AMRUT 24x7 Water Supply",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore, Tamil Nadu",
     "water_supply", "public_document", "official_budget_2023_24", "PDF",
     "Official municipal budget 2023-24 section AMRUT 24x7 Drinking Water Supply gives project-level planned/laid pipeline length, household connection and overhead tank progress. No route geometry is imported."),
    ("ccmc_engineering", "Coimbatore City Municipal Corporation",
     "Engineering Department — asset maintenance and UGSS reports",
     "https://ccmc.gov.in/index.php/services/Engineering", "Coimbatore, Tamil Nadu",
     "roads_water_sewerage", "public_web", "official_page_registered", "HTML",
     "Official CCMC Engineering page describes responsibility for roads, water supply, underground drainage and stormwater drainage. It lists project status reports 5.1–5.5. The page states 1,150 km of corporation roads/pavements maintained; no underground alignment GIS is published."),
    ("tnmaws_ugss_policy_2022", "Government of Tamil Nadu — Municipal Administration and Water Supply Department",
     "Tamil Nadu Legislative Assembly Policy Note / MAWS — sewerage scheme details",
     "https://www.tnurbantree.tn.gov.in/wp-content/uploads/2022/04/DIPR-TNLA-PN-MAWS-English-Date-07.04.2022.pdf",
     "Coimbatore, Tamil Nadu", "sewerage", "public_document", "official_government_report_2022", "PDF",
     "Government policy note dated 7 April 2022 reports the Kurichi and Kuniyamuthur underground sewerage scheme cost, beneficiary population and treatment capacity. These are scheme-level values, not verified line-by-line sewer network attributes."),
    ("tnurbanepay_building_approval_search", "Commissionerate of Municipal Administration, Tamil Nadu",
     "Citizen Web Portal — Building Plan Approval Search",
     "https://tnurbanepay.tn.gov.in/BPM_SearchLayoutApprovals.aspx", "Tamil Nadu ULBs",
     "building_approvals", "public_search", "official_public_search_verified", "HTML",
     "Public search form lists ULB, request type, approval date range and workflow status. Coimbatore City Municipal Corporation 2025 Approved search for one specified planning-permission request type returned zero records. No applicant personal data was collected."),
    ("ccmc_online_plan_approval", "Coimbatore City Municipal Corporation",
     "Online Plan Approval / AutoDCR description",
     "https://www.ccmc.gov.in/index.php/createpage/online-plan-approval", "Coimbatore, Tamil Nadu",
     "building_approvals", "public_web", "official_process_page_registered", "HTML",
     "CCMC explains its AutoDCR plan scrutiny and plan approval workflow. Process description only; it is not an export of original approval register records."),
    ("tnurban_ugss", "Commissionerate of Municipal Administration, Tamil Nadu",
     "Under Ground Drainage Scheme — ULB project status",
     "https://www.tnurbantree.tn.gov.in/under-ground-drainage-scheme/", "Tamil Nadu; includes Coimbatore",
     "sewerage", "public_web", "official_programme_page_registered", "HTML",
     "Tamil Nadu municipal administration public page summarises underground sewerage schemes and implementation programme. The page does not expose surveyed pipe alignment data."),
]


# project_key, project_name, authority, asset_domain, geography, coverage_areas,
# metric_key, metric_label, metric_value, unit, reference_year, source_key,
# source_url, source_title, source_reference, verification_status, notes
FACTS = [
    ("ccmc_stormwater", "CCMC stormwater drainage system", "Coimbatore City Municipal Corporation",
     "stormwater", "Coimbatore, Tamil Nadu", None, "maintained_drain_length",
     "Stormwater drains maintained", 603.50, "km", None, "ccmc_ugd",
     "https://www.ccmc.gov.in/index.php/department/ugd", "CCMC UGD Department",
     "CCMC UGD page states the corporation maintains 603.50 km of stormwater drains; accessed 6 Nov 2026.",
     "official_page_figure_undated",
     "Undated figure on the current public CCMC page. This is a citywide aggregate, not a geospatial layer or verified current asset-by-asset inventory."),
    ("ccmc_stormwater", "CCMC stormwater drainage system", "Coimbatore City Municipal Corporation",
     "stormwater", "Coimbatore, Tamil Nadu", None, "annual_new_drain_length",
     "New stormwater drains reported as added annually", 40, "km/year", None, "ccmc_ugd",
     "https://www.ccmc.gov.in/index.php/department/ugd", "CCMC UGD Department",
     "CCMC UGD page states 40 km of new stormwater drains are being constructed and added every year; accessed 6 Nov 2026.",
     "official_page_figure_undated",
     "CCMC webpage statement; source does not provide project dates or ward-level breakdown. Not a certified annual completion audit."),
    ("ccmc_water_distribution_historic", "CCMC municipal water distribution network (archived baseline)", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", None, "distribution_network_length",
     "Distribution network length (archived Citizen Charter)", 2380, "km", None, "ccmc_citizens_charter",
     "https://www.ccmc.gov.in/img/upload/CitizensCharterEnglish1.pdf", "CCMC Citizens Charter",
     "Citizen Charter Water Supply section; text uses 2011 Census population context and reports 2,380 km distribution network.",
     "official_historical_snapshot_undated",
     "Archived public document with no current survey date visible in extracted view. Historical context only; do not treat as current surveyed length or use for excavation clearance."),
    ("ccmc_water_distribution_historic", "CCMC municipal water distribution network (archived baseline)", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", None, "storage_reservoir_count",
     "Storage reservoirs (archived Citizen Charter)", 126, "reservoirs", None, "ccmc_citizens_charter",
     "https://www.ccmc.gov.in/img/upload/CitizensCharterEnglish1.pdf", "CCMC Citizens Charter",
     "Citizen Charter Water Supply section; reports 126 storage reservoirs with 2,380 km distribution network.",
     "official_historical_snapshot_undated",
     "Archived public document; date/baseline is not clear in the extracted view. Historical context only."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "Erstwhile 60 wards", "planned_distribution_pipeline_length",
     "Distribution pipelines planned", 1740, "km", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; scheme works in erstwhile 60 wards; planned length 1,740 km.",
     "official_budget_2023_24",
     "Budget progress figure; not a route dataset and not current as-built geometry."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "Erstwhile 60 wards", "laid_distribution_pipeline_length",
     "Distribution pipelines reported laid", 877, "km", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; 877 km of the 1,740 km planned distribution pipelines reported laid in the 2023-24 budget.",
     "official_budget_2023_24",
     "Reported progress in the 2023-24 budget; not a georeferenced as-built register."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "Erstwhile 60 wards", "planned_household_connections",
     "Household connections planned", 150000, "connections", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; target of 1,50,000 household connections.",
     "official_budget_2023_24",
     "Project-level plan target."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "Erstwhile 60 wards", "completed_household_connections",
     "Household connections reported completed", 43463, "connections", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; 43,463 household connections reported completed.",
     "official_budget_2023_24",
     "Progress figure as stated in the 2023-24 budget, not current live completion status."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "Erstwhile 60 wards", "overhead_tanks_total",
     "New overhead storage tanks planned", 33, "tanks", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; 33 new overhead storage tanks planned.",
     "official_budget_2023_24",
     "Project-level planned count."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "Erstwhile 60 wards", "overhead_tanks_under_construction",
     "New overhead storage tanks reported under construction", 27, "tanks", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; construction of 27 of 33 new overhead tanks reported in progress.",
     "official_budget_2023_24",
     "Progress figure as stated in the 2023-24 budget."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "Jayaram Nagar; Revathi Nagar; Cheran Nagar; Kamadenu Nagar; New Madathur; Kovilmedu",
     "households_24h_supply_reported", "Household connections reported with 24-hour supply", 4931, "connections", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; 4,931 household connections reported receiving 24-hour supply in six named localities.",
     "official_budget_2023_24",
     "Aggregate service metric only; locality names are service-area context, not pipe alignments."),
    ("amrut_24x7_water", "AMRUT 24x7 Drinking Water Supply Scheme", "Coimbatore City Municipal Corporation",
     "water_distribution", "Coimbatore, Tamil Nadu", "17 areas (not individually enumerated in budget extract)",
     "connections_served_through_new_pipelines", "Connections reported supplied through new pipelines", 20522, "connections", 2023, "ccmc_budget_2023_24",
     "https://www.ccmc.gov.in/img/upload/BUDGET/Cbe_Corp_Budget_23-24_English.pdf", "Coimbatore Corporation Budget 2023-24",
     "AMRUT 24x7 Drinking Water Supply section; 20,522 connections reported in 17 areas through new pipelines.",
     "official_budget_2023_24",
     "Aggregate service metric only; not an as-built geometry layer."),
    ("kurichi_kuniyamuthur_ugss", "Kurichi and Kuniyamuthur Underground Sewerage Scheme", "Government of Tamil Nadu / Coimbatore City Municipal Corporation",
     "sewerage", "Coimbatore, Tamil Nadu", "Kurichi; Kuniyamuthur", "project_cost",
     "Underground sewerage scheme estimated cost", 591.14, "INR crore", 2022, "tnmaws_ugss_policy_2022",
     "https://www.tnurbantree.tn.gov.in/wp-content/uploads/2022/04/DIPR-TNLA-PN-MAWS-English-Date-07.04.2022.pdf", "Tamil Nadu MAWS Policy Note / DIPR, 7 April 2022",
     "Table 6.11; estimated cost for Kurichi and Kuniyamuthur areas of Coimbatore Corporation.",
     "official_government_report_2022",
     "Government scheme-level figure as of the 2022 policy note; not a current financial statement."),
    ("kurichi_kuniyamuthur_ugss", "Kurichi and Kuniyamuthur Underground Sewerage Scheme", "Government of Tamil Nadu / Coimbatore City Municipal Corporation",
     "sewerage", "Coimbatore, Tamil Nadu", "Kurichi; Kuniyamuthur", "population_benefitted",
     "Population benefitted (reported estimate)", 5.17, "lakh people", 2022, "tnmaws_ugss_policy_2022",
     "https://www.tnurbantree.tn.gov.in/wp-content/uploads/2022/04/DIPR-TNLA-PN-MAWS-English-Date-07.04.2022.pdf", "Tamil Nadu MAWS Policy Note / DIPR, 7 April 2022",
     "Table 6.11; reported population benefitted 5.17 lakh for Kurichi and Kuniyamuthur.",
     "official_government_report_2022",
     "Government scheme-level figure as of the 2022 policy note."),
    ("kurichi_kuniyamuthur_ugss", "Kurichi and Kuniyamuthur Underground Sewerage Scheme", "Government of Tamil Nadu / Coimbatore City Municipal Corporation",
     "sewerage", "Coimbatore, Tamil Nadu", "Kurichi; Kuniyamuthur", "treatment_capacity",
     "Sewage treatment capacity", 30.53, "MLD", 2022, "tnmaws_ugss_policy_2022",
     "https://www.tnurbantree.tn.gov.in/wp-content/uploads/2022/04/DIPR-TNLA-PN-MAWS-English-Date-07.04.2022.pdf", "Tamil Nadu MAWS Policy Note / DIPR, 7 April 2022",
     "Table 6.11; reported treatment capacity 30.53 MLD for Kurichi and Kuniyamuthur.",
     "official_government_report_2022",
     "Scheme-level treatment capacity; does not reveal collection pipe alignments."),
    ("tnufip_added_areas_ugss", "TNUFIP Tranche 3 UGSS — added Coimbatore areas", "Coimbatore City Municipal Corporation / Tamil Nadu Urban Fund",
     "sewerage", "Coimbatore, Tamil Nadu", "Vadavalli; Veerakeralam; Kavundampalayam; Thudiyalur",
     "named_added_area_count", "Added areas named in CCMC public project reference", 4, "areas", None, "ccmc_ugd",
     "https://www.ccmc.gov.in/index.php/department/ugd", "CCMC UGD Department",
     "CCMC UGD page lists Tranche 3 UGSS for the four added areas.",
     "official_project_scope_reference",
     "Area names are project-scope references only. No route geometry or localised underground asset positions are stored."),
    ("ccmc_roads", "CCMC roads and pavements maintained", "Coimbatore City Municipal Corporation",
     "roads", "Coimbatore, Tamil Nadu", None, "maintained_road_length",
     "Tar and cement-concrete roads maintained (CCMC Engineering page)", 1150, "km", None, "ccmc_engineering",
     "https://ccmc.gov.in/index.php/services/Engineering", "CCMC Engineering Department",
     "CCMC Engineering page states 1,150 km of tar and cement-concrete roads are maintained.",
     "official_page_figure_undated",
     "Undated page figure; infrastructure context only, not road centerline geometry or current resurfacing status."),
]


def main() -> int:
    conn = connect()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(DDL)

                for row in SOURCES:
                    cur.execute(
                        """
                        insert into public.official_data_sources
                          (source_key, agency, dataset_name, source_url, geography,
                           data_theme, access_mode, integration_status, format,
                           last_checked_at, notes)
                        values (%s,%s,%s,%s,%s,%s,%s,%s,%s,now(),%s)
                        on conflict (source_key) do update set
                          agency=excluded.agency,
                          dataset_name=excluded.dataset_name,
                          source_url=excluded.source_url,
                          geography=excluded.geography,
                          data_theme=excluded.data_theme,
                          access_mode=excluded.access_mode,
                          integration_status=excluded.integration_status,
                          format=excluded.format,
                          last_checked_at=now(),
                          notes=excluded.notes
                        """,
                        row,
                    )

                execute_values(
                    cur,
                    """
                    insert into public.infrastructure_project_facts
                      (project_key, project_name, issuing_authority, asset_domain,
                       geography, coverage_areas, metric_key, metric_label, metric_value,
                       metric_unit, reported_reference_year, source_key, source_url,
                       source_title, source_reference, verification_status,
                       operational_use_allowed, geometry_available, notes,
                       last_verified_at, updated_at)
                    values %s
                    on conflict (project_key, metric_key, source_key) do update set
                      project_name=excluded.project_name,
                      issuing_authority=excluded.issuing_authority,
                      asset_domain=excluded.asset_domain,
                      geography=excluded.geography,
                      coverage_areas=excluded.coverage_areas,
                      metric_label=excluded.metric_label,
                      metric_value=excluded.metric_value,
                      metric_unit=excluded.metric_unit,
                      reported_reference_year=excluded.reported_reference_year,
                      source_url=excluded.source_url,
                      source_title=excluded.source_title,
                      source_reference=excluded.source_reference,
                      verification_status=excluded.verification_status,
                      operational_use_allowed=false,
                      geometry_available=false,
                      notes=excluded.notes,
                      last_verified_at=now(),
                      updated_at=now()
                    """,
                    [tuple(row[:-1]) + (False, False, row[-1]) for row in FACTS],
                    template="(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,now(),now())",
                )

                cur.execute(
                    """
                    insert into public.building_approval_search_audits
                      (query_fingerprint, issuing_authority, ulb_name, portal_url,
                       request_type, approval_from_date, approval_to_date,
                       status_filter, result_count, result_status,
                       observed_result_fields, personal_data_collected, notes)
                    values (
                      'TNURBANEPAY:CCMC:2025:APPROVED:BELOW12M',
                      'Commissionerate of Municipal Administration, Tamil Nadu',
                      'COIMBATORE CITY MUNICIPAL CORPORATION',
                      'https://tnurbanepay.tn.gov.in/BPM_SearchLayoutApprovals.aspx',
                      'Planning Permission With Building License Request (Below 12 meters)',
                      date '2025-01-01', date '2025-12-31', 'Approved', 0,
                      'no_records_returned',
                      array['Request Type','Service Request No','Approval No','Approval Date','Status','Action'],
                      false,
                      'Public official portal search performed 6 Nov 2026. No matching records returned for this exact ULB, request type, approval-date window and Approved status. This is a query result only; it is not proof that no permits were issued through other channels or request types. No applicant or property personal data was collected.'
                    )
                    on conflict (query_fingerprint) do update set
                      result_count=0,
                      result_status='no_records_returned',
                      personal_data_collected=false,
                      notes=excluded.notes,
                      queried_at=now()
                    """
                )

                cur.execute("select count(*) from public.infrastructure_project_facts")
                facts_count = cur.fetchone()[0]
                cur.execute("select count(*) from public.official_data_sources where source_key in %s",
                            (tuple(row[0] for row in SOURCES),))
                sources_count = cur.fetchone()[0]
                cur.execute("select count(*) from public.building_approval_search_audits")
                audits_count = cur.fetchone()[0]
                cur.execute("select count(*) from public.building_approval_records")
                approval_records_count = cur.fetchone()[0]

        summary = {
            "official_utility_project_facts": facts_count,
            "official_source_registry_rows": sources_count,
            "building_approval_search_audits": audits_count,
            "original_building_approval_records": approval_records_count,
            "exact_underground_geometry_imported": 0,
            "exact_geometry_reason": "Public aggregate sources are not surveyed asset GIS. Exact underground route geometry is not stored in the general application database.",
            "all_project_facts_geometry_available": False,
            "all_project_facts_operational_use_allowed": False,
        }
        print(json.dumps(summary, indent=2), flush=True)
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
