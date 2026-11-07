create table if not exists gis.building_footprint_source_registry (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique,
  provider text not null,
  dataset_name text not null,
  geography text not null,
  source_url text not null,
  data_license text not null,
  geometry_type text not null default 'building_footprint_polygon',
  height_attributes text,
  data_status text not null,
  imported_feature_count bigint not null default 0 check (imported_feature_count >= 0),
  operational_use_allowed boolean not null default false,
  attribution text,
  notes text,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table gis.building_footprint_source_registry enable row level security;
grant usage on schema gis to authenticated;
grant select on gis.building_footprint_source_registry to authenticated;

drop policy if exists authenticated_read_building_footprint_sources
  on gis.building_footprint_source_registry;
create policy authenticated_read_building_footprint_sources
  on gis.building_footprint_source_registry
  for select to authenticated
  using (true);

insert into gis.building_footprint_source_registry
(source_key,provider,dataset_name,geography,source_url,data_license,height_attributes,data_status,imported_feature_count,operational_use_allowed,attribution,notes,last_verified_at)
values
(
 'openfreemap_osm_vector_tiles',
 'OpenFreeMap / OpenStreetMap contributors',
 'OpenMapTiles Liberty vector basemap',
 'Global; rendered at viewport scale',
 'https://tiles.openfreemap.org/styles/liberty',
 'OpenFreeMap style: MIT; OpenStreetMap database: ODbL 1.0',
 'OSM building height / render_height / render_min_height where present; app fallback massing is explicitly estimated',
 'live_map_tile_source',
 0,
 true,
 'OpenFreeMap © OpenMapTiles; data from OpenStreetMap contributors',
 'Live vector-tile source used by the app map. Building polygons are streamed at map viewport scale and are not copied into Supabase. Not an official building-approval register; geometry completeness and heights vary by location.',
 now()
),
(
 'microsoft_global_ml_building_footprints',
 'Microsoft',
 'Global ML Building Footprints',
 'Global, including India',
 'https://github.com/microsoft/GlobalMLBuildingFootprints',
 'CDLA Permissive 2.0',
 'Height estimates exist only for a subset and must be checked per tile; footprint geometry is ML-derived',
 'catalogued_not_imported',
 0,
 false,
 'Microsoft Global ML Building Footprints',
 'Open dataset source identified for future regional ingestion. No geometry has been imported into this database; source imagery dates and positional accuracy vary.',
 now()
),
(
 'google_open_buildings_v3',
 'Google Research',
 'Open Buildings V3',
 'Global South including India',
 'https://sites.research.google/open-buildings/',
 'CC BY 4.0 (verify current release terms before redistribution)',
 'Building footprints and confidence scores; not a verified statutory height register',
 'catalogued_not_imported',
 0,
 false,
 'Google Research Open Buildings',
 'Potential footprint enrichment source. No geometry has been imported into this database; predictions require local validation and confidence filtering.',
 now()
),
(
 'open_building_map_global',
 'GFZ Data Services / OpenBuildingMap',
 'OpenBuildingMap',
 'Global',
 'https://www.openbuildingmap.org/',
 'ODbL 1.0',
 'Estimated height and floorspace derived from source datasets and GHSL; not surveyed building heights',
 'catalogued_not_imported',
 0,
 false,
 'OpenBuildingMap',
 'Potential enrichment dataset combining OSM, Google Open Buildings and Microsoft footprints. Height and occupancy are inferred; retain provenance and uncertainty.',
 now()
)
on conflict (source_key) do update set
 provider=excluded.provider,
 dataset_name=excluded.dataset_name,
 geography=excluded.geography,
 source_url=excluded.source_url,
 data_license=excluded.data_license,
 height_attributes=excluded.height_attributes,
 data_status=excluded.data_status,
 attribution=excluded.attribution,
 notes=excluded.notes,
 last_verified_at=now(),
 updated_at=now();
