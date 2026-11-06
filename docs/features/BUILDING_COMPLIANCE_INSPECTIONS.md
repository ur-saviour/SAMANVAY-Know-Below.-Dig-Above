# Building height and floor compliance inspections

## Purpose
Record field observations for building-planning cases and compare observed floor counts/heights with approval information entered by the responsible authority.

## Workflow
- Staff open an existing `building_planning` case.
- The inspector records the responsible department, approval reference/authority, approved floor count and/or height, observed floor count and optional observed height.
- The inspector selects a review state: awaiting review, reviewed consistent, or refer to competent authority.
- Each inspection is append-only. A new inspection is recorded for a later visit rather than overwriting the earlier observation.

## Safety and interpretation
A difference between observed and approved values is an inspection flag only. It does not establish an unlawful construction, determine a statutory breach, or replace verification against the approved plan and review by the competent planning authority. SAMANVAY stores the observation and audit trail; it does not issue enforcement decisions.

## Access control
- Requesters can read inspection records attached to their own case.
- Administrators and coordinators can read and create records.
- Department users can read and create records only for cases assigned to their department, with the responsible department matching their profile.
- No update or delete policy is provided; the inspection trail is append-only.
- Anonymous access is revoked; authenticated users receive only SELECT and INSERT grants, with RLS applied.

## Data quality
Floor counts and heights must be non-negative. At least one approval datum (approved floor count, approved height, or approval reference) is required. Observed floor count is mandatory. Heights are stored in metres.

## Operational limitation
The register contains no imported building approvals or authoritative building-footprint/floor datasets by default. A field observation must be checked against an authentic approval record before any regulatory conclusion.
