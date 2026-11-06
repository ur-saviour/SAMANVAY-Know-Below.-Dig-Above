# Stormwater Drainage & Frontage Inspection Tracking — Feature 4

## Purpose
Record and coordinate reported stormwater-drainage issues, including blocked inlets, silt/debris, drain encroachment, damaged drains, missing frontage drains, inadequate capacity and standing water. This is a municipal case-management workflow; it does not certify drainage capacity, determine statutory violations or replace engineering inspection.

## Workflow
1. A requester or staff member submits an infrastructure case with category \`stormwater_drainage\`.
2. Assigned department staff, coordinators or administrators open the Stormwater & Frontage Drainage panel.
3. Staff link an inspection record to the case and responsible department.
4. They record the observed issue, severity, action status, standing-water condition, inlet/outfall checks, frontage-drain presence and notes.
5. The record is upserted through \`public.save_drainage_inspection_record\`. A changed action status with notes also creates a \`public.case_inspections\` progress event in the same transaction.
6. The record can be updated through reported, inspection required, action assigned, in progress, cleared and monitoring states.

## Clearance gate
A record cannot be marked \`cleared\` unless:
- the drain inlet is verified clear;
- the outfall/discharge path is verified clear; and
- standing water is not observed.

The same rule is enforced by a PostgreSQL check constraint, not only by the Flutter form. A cleared case remains a recorded staff assessment, not a guarantee against future flooding.

## Data model
Table: \`public.drainage_inspection_records\`

- Case/owner: \`request_id\`, \`responsible_department_id\`.
- Issue classification: \`obstruction_type\`, \`severity\`, \`action_status\`.
- Field checks: \`standing_water\`, \`inlet_clear\`, \`outfall_clear\`, \`frontage_drain_present\`.
- Evidence notes: \`inspection_notes\`, \`inspected_at\`.
- Accountability: \`created_by\`, \`updated_by\`, \`created_at\`, \`updated_at\`.

One record is maintained per case and responsible department. The database records inspection/action changes in the existing case-inspection history when notes are supplied.

## Access model
RLS is enabled. Requesters can read records attached to their own cases. Department officers can read/create/update only records for requests assigned to their department and only when their profile department matches the responsible department. Coordinators and administrators can oversee records across departments. Anonymous/public access is revoked; there is no delete policy. The RPC is \`SECURITY INVOKER\`, so caller grants and RLS remain in force; execution is granted to authenticated users only.

## Application integration
The Stormwater & Frontage Drainage board appears in staff operational dashboards. It offers a record/update form for cases categorised as \`stormwater_drainage\`. The panel loads records visible through RLS and supports manual refresh. The form records observations and workflow state; it does not create drain geometry or infer the location of underground assets.

## Validation and current data status
- Supabase migration applied successfully.
- The table has RLS enabled and SELECT/INSERT/UPDATE policies for the intended roles.
- The save RPC was tested as an authenticated admin inside a transaction: a reported inspection was saved, then advanced to cleared with all three clearance checks satisfied; one record and two progress-history events were observed.
- The test transaction was rolled back; no permanent QA case, inspection or drainage record was retained.
- The live drainage-inspection table currently contains no operational records until authorised staff enter real inspections.
- No drain-network geometry or official municipal drainage inventory has been imported by this feature.

## Operational dependencies
Before operational rollout, the competent road/drainage authority must define its inspection checklist, service-level targets, responsibility boundaries and acceptance criteria. Record actual site observations and evidence. Do not interpret an absent record or empty map as evidence that no drain exists or that an area is flood-safe.
