# Utility proximity conflict screening — Feature 2

## Purpose

Identify active work requests that may be close to registered underground utilities across departments. Results are advisory and require owner-department review and field verification. They are not excavation permits, utility clearances, strike predictions, or substitutes for site surveys.

## Application workflow

- Runs for authenticated staff roles: assigned department, coordinator and admin.
- The map loads all RLS-visible requests in the current viewport plus a 1 km buffer, in 500-row pages.
- Completed, resolved, rejected and cancelled requests are excluded from screening.
- A request must have an entered `work_radius_m`. The request form accepts 1–500 m; a blank radius is not silently changed to a default.
- Requests are screened in batches of up to 500 IDs through `public.get_map_utility_conflict_advisories`.
- The PostGIS function runs on the server against **verified assets across all departments**. It uses geography distance for Point, MultiPoint, LineString and MultiLineString geometries.
- The effective horizontal screening buffer is the entered work radius + the asset's recorded horizontal accuracy (capped at 500 m) + a 3 m conservative guard buffer.
- The function returns only minimum advisory metadata: request number, asset type, owning department, horizontal distance, recorded depth and recorded horizontal accuracy.
- It does not return asset IDs, asset codes, asset names, coordinates or geometry.
- Red markers appear at affected work-request locations. Tapping a marker shows the owning department and proximity details. The GIS layer panel shows the affected request list and screening state.
- The separate verified-department-assets map layer remains owner-only and can show exact geometry only to the owning department. It is not used by the cross-department screening endpoint.

## Database and security controls

- The endpoint requires a valid authenticated profile with role `department`, `coordinator` or `admin`.
- Coordinators and admins may screen requests visible to their role. Department users may screen only requests assigned to their department through the existing assignment-check function.
- A requester profile is rejected by the endpoint.
- The RPC checks every supplied request ID and rejects the batch if any ID is unavailable or not assigned to the caller.
- The endpoint is `SECURITY DEFINER` with an empty search path, fully qualified table/function references, explicit `auth.uid()` checks, and execution revoked from `PUBLIC` and `anon`; only `authenticated` is granted execution.
- A partial GiST expression index on verified assets' geography representation supports the spatial proximity lookup.
- The existing `run_request_coordination_check` was hardened to ignore unverified assets and return `unavailable` when no verified assets exist.
- The endpoint returns a `geometry_disclosed: false` marker and a no-clearance disclaimer.

## Interpretation limits

- The check is horizontal proximity only. Asset depth is returned when recorded, but the request form does not capture excavation depth, so vertical clearance is not calculated.
- The entered work radius is user-provided and is not a surveyed excavation boundary.
- Unknown horizontal accuracy remains unknown; the system does not fabricate an uncertainty value.
- No match means only that no verified registered asset matched the query. It does not prove that a site is utility-free or safe.
- Incomplete asset coverage, stale surveys, inaccurate geometry, unregistered services and unknown vertical alignment can cause false positives or false negatives.
- The current underground asset registry has zero records. The server endpoint and app workflow are implemented and tested with temporary synthetic records, but real operational warnings require owner-authorised utility data to be imported and verified.

## Validation performed

A transaction-based QA test inserted one temporary verified asset and one temporary unverified asset near a temporary work request, called the RPC as an admin, then rolled back all test data. Results:
- The request was marked `potential_conflict`.
- Exactly one candidate was returned, confirming the unverified asset was excluded.
- The result disclosed no asset identity or geometry.
- A requester-role call was rejected.
- All temporary test rows were rolled back.

## Release checklist

1. Verify Flutter static analysis and Android APK build in GitHub Actions before distributing an APK.
2. Test department users against assigned and unassigned requests; unassigned requests must be rejected.
3. Test coordinator/admin access and requester denial.
4. Test missing location, missing radius, 1 m and 500 m radii.
5. Test Point, MultiPoint, LineString and MultiLineString assets, including proximity to the middle of a line segment.
6. Confirm unverified, disputed and retired records never produce warnings.
7. Confirm the RPC never returns asset codes, IDs, names, coordinates or geometry.
8. Confirm screening failure is displayed as unavailable, never as a clear site.
9. Import only owner-authorised source records and complete verification before treating the layer as operational.
10. Add excavation depth to the request schema and form before implementing vertical-clearance analysis.

## Operational prerequisites

- Obtain owner-authorised utility records or conduct verified field surveys.
- Preserve source lineage, survey date, horizontal/vertical accuracy, depth where known, and verification evidence.
- Keep cross-department advisories server-side; do not grant mobile clients direct access to the private `gis` schema.
