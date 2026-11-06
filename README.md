# SAMANVAY — Know Below. Dig Above.

SAMANVAY is a multi-department municipal infrastructure coordination platform with a PostGIS-backed underground asset registry.

## Government data acquisition

The Tamil Nadu-first and national data acquisition plans are maintained here:

- [Tamil Nadu Official Data Acquisition Register](docs/data-governance/TAMIL_NADU_OFFICIAL_DATA_ACQUISITION_REGISTER.md)
- [Coimbatore Pilot Authority Mapping](docs/data-governance/COIMBATORE_PILOT_AUTHORITY_MAPPING.md)
- [Coimbatore Data-Sharing Request Templates](docs/data-governance/COIMBATORE_DATA_SHARING_REQUEST_TEMPLATE.md)
- [Coimbatore Open Reference Data Register](docs/data-governance/COIMBATORE_OPEN_REFERENCE_DATA_REGISTER.md)
- [India National Data Acquisition Register](docs/data-governance/INDIA_NATIONAL_DATA_ACQUISITION_REGISTER.md)

These are acquisition plans. They do not imply that government datasets, survey records, permissions or approvals have already been received.

## GIS asset data governance

- [Secure GIS Asset Ingestion and Verification](docs/data-governance/GIS_ASSET_INGESTION_AND_VERIFICATION.md)
- [Supabase Security and Performance Review](docs/security/SUPABASE_SECURITY_AND_PERFORMANCE_REVIEW_2026-11-06.md)
- GeoJSON ingestion is restricted to authenticated department accounts.
- Exact utility geometry remains server-side; mobile map views use approved generalised coverage.
- Imported assets remain UNVERIFIED until authorised evidence and verification are recorded.
- An empty registry is not evidence that underground utilities are absent.

## Application

- Flutter Android application: `app/main.dart`
- Supabase migrations: `supabase/migrations/`
- Supabase Edge Functions: `supabase/functions/`
- Current development branch: `feature/alpha-03-integrated-platform`

## Build

Android and browser build workflows are maintained in `.github/workflows/`. Downloadable build artifacts are available from the GitHub Actions run page.
