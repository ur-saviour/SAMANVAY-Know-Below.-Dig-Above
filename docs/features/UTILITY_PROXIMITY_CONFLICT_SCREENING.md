# Utility proximity conflict screening — Feature 2

## Purpose

Flag active, location-based work requests that may be close to registered underground utility assets. The result is an advisory for authorised departmental review. It is not an excavation permit, utility clearance, strike prediction, or substitute for a site survey / utility-owner confirmation.

## Current application behaviour

- Runs in the GIS map for an authenticated user whose profile is an assigned `department` account.
- Uses the existing `get_my_department_verified_assets_geojson` RPC. The RPC derives the caller's department from the authenticated session and returns only verified assets owned by that department in the requested map area.
- Does not read unverified asset geometry and does not substitute basemap features, public reference layers, telemetry stations, estimated routes, or empty-data assumptions.
- Loads all RLS-visible request rows in the current map extent plus a 1 km buffer, in 500-row pages. The asset query uses the same 1 km buffer so nearby line geometry can be considered even when it lies just outside the visible screen.
- Screens active requests only. Completed, resolved, rejected and cancelled requests are excluded.
- A request must have an explicitly entered `work_radius_m`. The optional form field accepts 1–500 m; a blank value does not silently become a 15 m work radius.
- Compares the request point with the nearest point/segment of supported GeoJSON geometries: Point, MultiPoint, LineString and MultiLineString.
- Adds the asset's recorded `horizontal_accuracy_m` to the entered work radius as a conservative horizontal uncertainty buffer (capped at 500 m). Unknown accuracy is not invented.
- Shows red markers at candidate work-request locations, plus request number, asset code/type, measured horizontal distance, recorded depth and recorded horizontal accuracy.
- Shows screening status and the first five candidate records in the GIS layer panel. Additional candidates remain available through their map markers.
- Hiding the verified-asset layer also hides and clears the visible conflict results. Re-enabling it reruns the screening.

## Access and data governance

Exact underground geometry remains within the existing department-scoped RPC boundary. This mobile implementation does **not** expose another department's exact utility geometry. The UI explicitly labels that scope. Do not broaden the RPC grants or grant mobile users direct access to the private `gis` schema to make a map overlay work.

Cross-department coordination is a separate backend capability: it should run the spatial comparison server-side and return only minimum necessary advisory metadata to authorised coordinators, without returning another owner's exact geometry. It is not claimed as implemented by this client-side feature.

## Interpretation limits

- The check is horizontal proximity only. Asset `depth_m` is displayed when recorded, but the request form does not currently capture excavation depth, so vertical clearance cannot be computed.
- The work-site radius is user-entered and is not a surveyed excavation boundary.
- Horizontal distance uses a local metre-based projection for short municipal work corridors. It is a screening estimate, not cadastral or engineering survey output.
- A result may be false positive or false negative because of geometry quality, survey date, positional accuracy, incomplete asset coverage, unregistered utilities, or unknown vertical alignment.
- No warning means only that no candidate was found in the verified assets returned for this department and map extent. It never means the site is utility-free or safe to excavate.
- The current underground asset registry has been reported as empty. Until authorised assets are imported and verified, live detection cannot produce meaningful coverage.

## Release validation checklist

1. Assigned department user sees only their own department's verified assets and receives the screening panel.
2. Request with blank radius is not screened.
3. Request with 1 m, 100 m and 500 m radii uses the entered range without silently changing it.
4. Completed/resolved/rejected/cancelled requests are excluded.
5. Point and MultiPoint assets trigger when within the effective horizontal buffer.
6. LineString and MultiLineString assets trigger when the request point is near a segment, including when it is near the middle of a long segment rather than a vertex.
7. Recorded horizontal accuracy widens the advisory buffer; missing accuracy remains unknown and is not fabricated.
8. Unverified assets never trigger warnings.
9. Request and asset records outside the current map buffer do not appear in this map's screening result.
10. A GIS/RPC failure displays an unavailable state, never a "clear" state.
11. Hiding verified assets hides markers and clears the displayed list; turning the layer back on reruns screening.
12. Requester, coordinator and admin roles do not receive exact department-owned utility geometry through this department-only map RPC.
13. Verify Flutter static analysis and the Android APK build in GitHub Actions before distributing an APK.

## Remaining prerequisites for operational use

- Obtain owner-authorised underground utility records or complete verified field surveys.
- Have the asset owner record source lineage, survey date, horizontal/vertical accuracy, depth where known, and verification evidence.
- Implement the separate server-side cross-department advisory endpoint before claiming city-wide interdepartmental clash detection.
- Add excavation depth to the work request schema and form before attempting vertical-clearance assessment.
