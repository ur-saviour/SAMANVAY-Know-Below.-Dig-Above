# Road Restoration & Quality Assurance

## Purpose

SAMANVAY records what happens after a road is opened for utility installation, repair or maintenance. The workflow provides a traceable record of the road surface, dimensions, planned restoration date, restoration method, inspection outcome and quality checks.

This feature is intended to reduce incomplete reinstatement, repeated road failures and blocked drainage paths. It is a case-management and evidence workflow; it does not replace statutory road specifications, engineering supervision, or a competent authority's acceptance process.

## Workflow

1. A department officer, coordinator or administrator opens the restoration panel in the staff operations dashboard.
2. The officer links a restoration record to an accessible infrastructure case and identifies the responsible department.
3. The record captures surface type, optional cut/restored dimensions, method, planned date and quality notes.
4. The officer progresses the record through planned, in progress and awaiting inspection.
5. The authorised inspection outcome is recorded as accepted or rework required. The app also writes the inspection outcome to `public.case_inspections` as a post-work inspection event.
6. The restoration record remains visible to the requester and authorised staff. Rework can be recorded and tracked rather than silently marked complete. The save path uses a single `SECURITY INVOKER` RPC so the restoration upsert and any changed post-work inspection event commit atomically.

## Acceptance controls

A record cannot enter the accepted state unless all of the following are true:

- The inspection outcome is accepted.
- Compaction / surface preparation is verified.
- The drainage path is clear.
- A completion timestamp is present.

The database also enforces consistency between the restoration status and the inspection outcome. A rework-required inspection must be paired with a rework-required restoration status. These checks are enforced in PostgreSQL, not only in the Flutter form.

## Data model

Table: `public.road_restoration_records`

Key fields include:

- Case and responsible department: `request_id`, `responsible_department_id`.
- Road details: `road_surface_type`, `cut_length_m`, `cut_width_m`, `restored_length_m`, `restored_width_m`.
- Delivery tracking: `restoration_status`, `restoration_method`, `planned_restore_date`, `completed_at`.
- Quality and inspection: `inspection_outcome`, `compaction_verified`, `drainage_clear`, `surface_quality_notes`.
- Accountability: `created_by`, `updated_by`, `created_at`, `updated_at`.

The table has a unique constraint per case and responsible department, measurement bounds, foreign keys and indexes for status/due-date and case-history lookups. Updates automatically refresh `updated_at`.

## Access model

Row-level security is enabled.

- Requesters can read restoration records connected to their own cases.
- Department officers can create and update records only for cases assigned to their department, and only where their profile department matches the responsible department.
- Coordinators and administrators can oversee records across departments.
- Anonymous/public access is revoked. Authenticated users receive read/insert privileges and a column-limited update grant. There is no delete policy.

The database remains the authority for permissions. The Flutter UI only presents cases already accessible to the signed-in role.

## Application integration

A restoration board appears on the department, coordinator and admin operational dashboards. It loads the latest 100 records, supports refresh, and provides a record/update form. Department users are limited to their assigned department; coordinator/admin users can select from departments and cases returned by their permissions.

A changed inspection outcome is additionally logged in `public.case_inspections` using the existing post-work inspection workflow.

## Validation and current data status

- Supabase confirms the table exists with RLS enabled and the three intended SELECT, INSERT and UPDATE policies.
- Database check constraints enforce acceptance gates and inspection/status consistency.
- The acceptance gate and atomic save RPC were tested as an authenticated admin inside a transaction: a planned record was saved, advanced to accepted, then saved again; exactly one post-work inspection event and a completion timestamp were observed. The test transaction was rolled back and creates no permanent case data.
- The RPC is `SECURITY INVOKER`, uses the caller's RLS permissions, revokes execution from `PUBLIC` and `anon`, and grants execution only to `authenticated`.
- The live restoration table currently contains zero rows. Records appear only after authorised staff enter real work information.
- The current v1 form does not generate engineering certification and does not automatically infer road dimensions or surface condition from imagery.
- Photos and reports can use the existing case evidence workflow; dedicated evidence controls are not yet embedded inside this restoration panel.

## Deployment dependencies

Before operational rollout, road-owning authorities should define the applicable reinstatement specifications, inspection checklists, restoration time limits and acceptance authority. Department officers should enter measured site information and retain source evidence. The app must not treat a missing restoration record as proof that a road has been restored.
