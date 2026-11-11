insert into public.official_data_sources
  (source_key, agency, dataset_name, source_url, geography, data_theme, access_mode, integration_status, format, notes)
values
  (
    'india_geoboundaries_adm1_reference',
    'DataMeet India community / Election Commission of India (catalogued by geoBoundaries)',
    'India State and Union Territory administrative boundaries (ADM1)',
    'https://www.geoboundaries.org/api/current/gbOpen/IND/ADM1/',
    'India — 36 State / Union Territory units; reference only',
    'administrative_directory',
    'public_download',
    'metadata_registered',
    'Simplified GeoJSON (runtime retrieval)',
    'Published vintage 2011; source metadata reports DataMeet India community and Election Commission of India; licence: Creative Commons Attribution 2.5 India. Non-statutory visual reference; not an LGD code directory or current legal boundary certification.'
  ),
  (
    'india_geoboundaries_adm2_reference',
    'Pathways Data Pvt. Ltd. / Local Government Directory (catalogued by geoBoundaries)',
    'India district administrative boundaries (ADM2)',
    'https://www.geoboundaries.org/api/current/gbOpen/IND/ADM2/',
    'India — 736 district units; reference only',
    'administrative_directory',
    'public_download',
    'metadata_registered',
    'Simplified GeoJSON (runtime retrieval)',
    'Published vintage 2021; source metadata reports Pathways Data Pvt. Ltd. and Local Government Directory; licence: Open Data Commons Open Database License 1.0. Non-statutory visual reference; not a current LGD export or LGD-code reconciliation.'
  )
on conflict (source_key) do update set
  agency = excluded.agency,
  dataset_name = excluded.dataset_name,
  source_url = excluded.source_url,
  geography = excluded.geography,
  data_theme = excluded.data_theme,
  access_mode = excluded.access_mode,
  integration_status = excluded.integration_status,
  format = excluded.format,
  notes = excluded.notes,
  last_checked_at = now();