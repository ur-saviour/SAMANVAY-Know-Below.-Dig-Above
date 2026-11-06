# SAMANVAY GIS asset ingestion and verification

## Operational rule

Exact underground utility geometry is private infrastructure data. The mobile app must not receive direct access to the `gis` schema or the exact-geometry tables. The mobile map may display only the approved, generalised coverage RPC output.

## Import path

1. An authenticated user opens GIS Data Ingestion.
2. The app confirms the caller has a `department` profile and an assigned department.
3. The user selects an authorised GeoJSON FeatureCollection in WGS84 / EPSG:4326.
4. The client validates the preview (Point, MultiPoint, LineString, MultiLineString; maximum 10 MB and 500 features).
5. On confirmation, the app invokes `samanvay-asset-registry`.
6. The Edge Function validates the Supabase access token, loads the caller's profile server-side, and accepts only assigned department accounts.
7. The Edge Function calls `register_underground_asset_server` using its server-only secret. That database function re-checks the actor's department role, derives the owning department from `profiles`, validates the geometry and metadata, and records the creator.
8. Every imported record is assigned `verification_status = unverified` and `operational_status = unknown`.

## Supported metadata

Required: `asset_code`, `asset_name`, `asset_type`, `source_type`.

Optional: `source_reference`, `depth_m`, `horizontal_accuracy_m`, `vertical_accuracy_m`, `material`, `diameter_mm`, `surveyed_at`, `surveyed_by_org`, `verification_notes`.

Supported asset types: water, sewer, stormwater, electricity, telecom, gas, borewell, drain, other, unknown.

Supported source types: utility_owner, field_survey, as_built_drawing, public_dataset, estimated, other.

## Verification and publication

- Import is registration, not verification.
- No imported geometry is labelled verified automatically.
- A qualified owner or authorised survey process must provide source evidence and accuracy metadata.
- A separate authorised review must change verification status.
- Estimated or public basemap data must never be presented as surveyed utility geometry.
- A zero-record database result means no records are currently registered; it does not prove that no underground assets exist.

## Security boundary

- `gis` schema access remains revoked from mobile `authenticated` users.
- The server RPC is executable only by `service_role`; its service key is never embedded in Flutter or GitHub source.
- The Edge Function validates the user's bearer token and derives role/department from the database; it does not trust a client-supplied role or department ID.
- Exact geometry and survey evidence must not be sent to AI assessment prompts or exposed through general mobile list APIs.
