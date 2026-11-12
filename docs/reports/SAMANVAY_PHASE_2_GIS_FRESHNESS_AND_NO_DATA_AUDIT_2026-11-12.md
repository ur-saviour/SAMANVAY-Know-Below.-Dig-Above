# SAMANVAY Phase 2 — GIS freshness and no-data audit

**Audit date:** 12 November 2026  
**Target branch:** `feature/alpha-03-integrated-platform`  
**Implementation branch:** `feature/phase-2-gis-freshness-guardrails`

## Implemented in this change

The GIS groundwater layer now reports two different timestamps separately:

- The newest timestamp among the records loaded in the current map viewport (bounded by the existing 1,000-point display limit).
- The newest observation timestamp across the complete `latest_groundwater_station_observations` source archive.

The map UI explicitly labels the archive as historical monitoring data and **not live telemetry**. The source-wide timestamp is retrieved from the latest-per-station table, so a future authorised import can advance the displayed cutoff without a code edit. If this metadata query fails, the UI says the archive timestamp is unavailable rather than implying freshness.

## Live database validation

| Dataset / control | Result |
|---|---:|
| `groundwater_station_observations` | 446,068 observations |
| Observations with coordinates | 445,553 |
| Observations without coordinates | 515 |
| Distinct source agencies | 7 |
| Latest source observation | 2025-12-31 18:00 (source-local timestamp) |
| `latest_groundwater_station_observations` | 576 latest-per-station rows |
| Latest-per-station rows with coordinates | 574 |
| User-submitted `groundwater_observation_records` | 0 |
| `gis.underground_assets` | 0 |
| `gis.asset_survey_evidence` | 0 |

The observation archive is not a live telemetry feed. It is also not a borewell registry, permission register, or excavation clearance source.

## Boundary provenance and quality

The application map fetches public administrative reference geometry through the `samanvay-public-boundaries` Edge Function from geoBoundaries and displays the returned represented year, source and licence. Its UI already marks the boundaries as reference-only / non-statutory.

A separate database fallback, `public.india_district_boundary_reference`, contains 733 valid WGS84 district geometries from the DataMeet India district-boundary collection, with source-vintage labels spanning 2011–2019. It is a reference fallback, not the current geoBoundaries layer and not LGD-certified geometry. It must not be silently presented as an authoritative current jurisdiction layer.

## Excavation screening safeguards retained

The server-side `public.get_map_utility_conflict_advisories(uuid[])` function:

- Requires an authenticated staff account and checks request assignment.
- Compares requests only against assets with `verification_status = 'verified'`.
- Returns `unavailable_no_verified_assets` when no verified asset records exist.
- Does not disclose exact asset geometry to the mobile client.
- States that no proximity match is not utility clearance or proof of site safety.

The application status message likewise says screening is unavailable when the verified asset inventory is empty. No attempt was made to infer missing assets or generate synthetic underground routes.

## Outstanding Phase 2 blockers

1. No verified underground asset geometry or survey evidence is registered yet.
2. Official LGD bulk-export provenance and authority validation remain pending; the currently imported LGD-code directory mirror is not authority-certified.
3. ULB, ward and other local-body directory/geometry coverage requires authoritative source validation.
4. The historical groundwater archive needs a current, verified feed before it can be described as live.
5. Boundary references need jurisdiction-by-jurisdiction legal/authority confirmation before operational decisions.
6. Android release packaging and physical-device checks must complete before distribution readiness can be claimed.

## Verification note

The prior Android workflow had passed dependency installation and Dart analysis but was still running its release APK build at the time this audit was prepared. The web build and GIS asset smoke test had completed successfully. Final Android packaging, signature and alignment checks remain subject to the workflow result.
