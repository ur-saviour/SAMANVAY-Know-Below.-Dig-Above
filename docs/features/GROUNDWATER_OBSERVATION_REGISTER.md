# Groundwater and borewell observation register

## Purpose
Record dated field observations associated with a SAMANVAY borewell/groundwater case. This is a manual case-linked register, separate from the bundled Coimbatore public groundwater telemetry snapshot.

## Captured fields
- Site reference and well type (borewell, open well, observation well, other)
- Observation method (manual measurement, sensor reading, authority record, field inspection)
- Water level below ground level in metres
- Pumping state at the time of observation
- Source type/reference and notes
- Observation timestamp and authenticated creator

## Access and audit
- Requesters can read observations for their own groundwater case.
- Admins and coordinators can read and create observations.
- Department staff can read and create only for cases assigned to their department.
- The table is append-only for authenticated users: SELECT and INSERT only; no update or delete policy.
- Anonymous access is revoked and RLS is enabled.

## Interpretation limits
The register does not automatically classify a well as legal/illegal, sustainable/unsustainable, or safe/unsafe. A water-level reading is meaningful only with a timestamp, measurement method, pumping state, site context and source quality. Authority documents and sensor records must be independently verified. No live sensor connection is implied by this feature.
