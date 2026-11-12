-- Register OGD resource-level references to the official LGD district and
-- local-body catalogues. These are metadata/API references, not imported rows.
-- The app must keep district/ULB hierarchy empty until the source payloads
-- are retrieved, checksum-verified, schema-checked and reconciled by LGD code.

insert into public.official_data_sources
  (source_key,agency,dataset_name,source_url,geography,data_theme,
   access_mode,integration_status,format,last_checked_at,notes)
values
 ('india_lgd_districts_ogd',
  'Ministry of Panchayati Raj / Open Government Data Platform India',
  'Local Government Directory (LGD) — Districts',
  'https://data.gov.in/resource/local-government-directory-lgd-districts',
  'India — State/UT district directory with LGD codes',
  'Administrative directory and LGD code reference',
  'metadata_only','metadata_registered','OGD catalogue / sourced webservice API',now(),
  'OGD catalogue page reports monthly refresh and metadata updated 2026-10-27, and identifies the resource as LGD district codes sourced from the official LGD directory. This is a catalogue/API reference only: no API response or bulk file has been imported or reconciled by SAMANVAY. Confirm API key/access and payload schema before import; validate LGD codes and source date.'),
 ('india_lgd_local_bodies_ogd',
  'Ministry of Panchayati Raj / Open Government Data Platform India',
  'Local Government Directory (LGD) — Local Bodies',
  'https://data.gov.in/resource/local-government-directory-lgd-local-bodies',
  'India — urban and rural local bodies with LGD codes',
  'Administrative directory and LGD code reference',
  'metadata_only','metadata_registered','OGD catalogue / sourced webservice API',now(),
  'OGD catalogue page reports monthly refresh and metadata updated 2026-10-28, and identifies the resource as LGD local-body codes sourced from the official LGD directory. This is a catalogue/API reference only: no API response or bulk file has been imported or reconciled by SAMANVAY. Confirm API key/access and payload schema before import; validate LGD codes, hierarchy and source date.')
on conflict (source_key) do update set
 agency=excluded.agency,
 dataset_name=excluded.dataset_name,
 source_url=excluded.source_url,
 geography=excluded.geography,
 data_theme=excluded.data_theme,
 access_mode=excluded.access_mode,
 integration_status='metadata_registered',
 format=excluded.format,
 last_checked_at=now(),
 notes=excluded.notes;
