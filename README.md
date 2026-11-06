# SAMANVAY — Know Below. Dig Above.

SAMANVAY is a multi-department municipal infrastructure coordination platform with a PostGIS-backed underground asset registry.

## Government data acquisition

The Tamil Nadu-first and national data acquisition plans are maintained here:

- [Tamil Nadu Official Data Acquisition Register](docs/data-governance/TAMIL_NADU_OFFICIAL_DATA_ACQUISITION_REGISTER.md)
- [Coimbatore Pilot Authority Mapping](docs/data-governance/COIMBATORE_PILOT_AUTHORITY_MAPPING.md)
- [Coimbatore Data-Sharing Request Templates](docs/data-governance/COIMBATORE_DATA_SHARING_REQUEST_TEMPLATE.md)
- [Coimbatore Groundwater Telemetry Dataset](docs/data-governance/COIMBATORE_GROUNDWATER_TELEMETRY_DATASET.md)
- [Coimbatore Pilot Data Readiness and Evidence Draft](docs/data-governance/COIMBATORE_PILOT_DATA_READINESS_AND_EVIDENCE_DRAFT.md)
- [Coimbatore Open Reference Data Register](docs/data-governance/COIMBATORE_OPEN_REFERENCE_DATA_REGISTER.md)
- [Coimbatore Public Data Package — 6 November 2026](docs/data-governance/COIMBATORE_PUBLIC_DATA_PACKAGE_2026-11-06.md)
- [Coimbatore Public Data Evidence — Final Draft (6 November 2026)](docs/data-governance/COIMBATORE_DATA_EVIDENCE_FINAL_DRAFT_2026-11-06.md)
- [India National Data Acquisition Register](docs/data-governance/INDIA_NATIONAL_DATA_ACQUISITION_REGISTER.md)

These are acquisition plans. They do not imply that government datasets, survey records, permissions or approvals have already been received.

## GIS asset data governance

- [Secure GIS Asset Ingestion and Verification](docs/data-governance/GIS_ASSET_INGESTION_AND_VERIFICATION.md)
- [Supabase Security and Performance Review](docs/security/SUPABASE_SECURITY_AND_PERFORMANCE_REVIEW_2026-11-06.md)
- [Utility Proximity Conflict Screening](docs/features/UTILITY_PROXIMITY_CONFLICT_SCREENING.md)
- [Road Restoration and Quality Assurance](docs/features/ROAD_RESTORATION_QUALITY_ASSURANCE.md)
- [Coimbatore Open Reference Data Register](docs/data-governance/COIMBATORE_OPEN_REFERENCE_DATA_REGISTER.md)
- The app bundles an optional 2024 Coimbatore 100-ward public-domain reference layer at `assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson`.
- That boundary layer is an administrative reference only; it is not CCMC-certified statutory GIS and does not contain underground utility geometry.
- GeoJSON utility ingestion is restricted to authenticated department accounts.
- Exact utility geometry remains server-side; mobile map views use approved generalised coverage.
- Imported utility assets remain UNVERIFIED until authorised evidence and verification are recorded.
- An empty underground-asset registry is not evidence that underground utilities are absent.

- [Alpha 0.3 Coimbatore Pilot Delivery Record](docs/release/SAMANVAY_ALPHA_0_3_COIMBATORE_PILOT_DELIVERY.md)

- Official Coimbatore taluk waterbody PDF source index (11 links): `data/reference/coimbatore_waterbody_map_index.csv`.

## Application

- Flutter Android application: `app/main.dart`
- Supabase migrations: `supabase/migrations/`
- Supabase Edge Functions: `supabase/functions/`
- Current development branch: `feature/alpha-03-integrated-platform`

## Build

Android and browser build workflows are maintained in `.github/workflows/`. Downloadable build artifacts are available from the GitHub Actions run page.
