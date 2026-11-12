-- Register a current government-published India district boundary reference.
-- This is source metadata only. No district geometries or LGD codes are fabricated.
-- The NWIC page identifies GSI as producer, reports 733 districts, and lists
-- GeoJSON/KML/Shapefile resources with a 2025-05-05 update date.
-- Download, checksum, CRS validation and LGD reconciliation remain separate QA steps.

insert into public.official_data_sources
  (source_key, agency, dataset_name, source_url, geography, data_theme,
   access_mode, integration_status, format, last_checked_at, notes)
values
  ('india_nwic_district_boundary_gsi',
   'Geological Survey of India / National Water Informatics Centre',
   'India District Boundary — 733 district reference layer',
   'https://nwdp.nwic.gov.in/dataset/district-boundary',
   'India — 733 district boundary reference features',
   'Administrative GIS boundary reference',
   'public_download',
   'metadata_registered',
   'GeoJSON ZIP, KML, Shapefile',
   now(),
   'The NWIC dataset page identifies GSI as the producer and reports 733 district boundaries with a last update of 2025-05-05. Resource download links are listed. This record registers source metadata only: the file has not yet been downloaded, checksum-verified, CRS-validated, LGD-code reconciled or imported into SAMANVAY. It is not a current legal boundary certification, not the LGD district master and not underground utility geometry. Use for map reference only after download and QA.')
on conflict (source_key) do update set
  agency = excluded.agency,
  dataset_name = excluded.dataset_name,
  source_url = excluded.source_url,
  geography = excluded.geography,
  data_theme = excluded.data_theme,
  access_mode = excluded.access_mode,
  integration_status = 'metadata_registered',
  format = excluded.format,
  last_checked_at = now(),
  notes = excluded.notes;
