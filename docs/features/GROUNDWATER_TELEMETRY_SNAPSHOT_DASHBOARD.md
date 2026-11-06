# Groundwater Telemetry Snapshot Dashboard — Feature 5

## Purpose
Surface the already acquired Coimbatore district groundwater telemetry snapshot in the staff dashboard, rather than requiring users to open the GIS map and tap individual station markers.

## Data source and scope
- Source: National Water Data Portal / Tamil Nadu Surface Water and Ground Water Departments.
- Resource ID: \`6857c02f-c77e-4576-b349-3e45aacc1c21\`.
- Bundled file: \`assets/reference/coimbatore/groundwater_telemetry_2026_2030.geojson\`.
- Snapshot contains 21 station points for Coimbatore district.
- Latest observation present in this snapshot: Thenkarai, 5 November 2026 at 12:00, source reading -53.35 m.
- Observation times differ by station; the panel sorts by the parsed source timestamp and shows the five latest observations first, with an expandable list for the remaining stations.

## Application integration
The staff operational dashboard reads the bundled GeoJSON through Flutter's asset bundle, validates the FeatureCollection, extracts station properties and sorts observations by their recorded timestamp. It displays the station count, latest source timestamp, station name, tehsil (when supplied), source reading and RL MSL field (when supplied).

The map's existing groundwater telemetry layer remains available for spatial context and marker-level details. The dashboard is a summary view of the same snapshot, not a new data feed.

## Interpretation and limitations
- The data is a dated snapshot, not a live or continuously refreshed telemetry connection.
- Station timestamps differ; the latest timestamp is not the observation time for every station.
- Source values are displayed as published. The app does not infer safe/unsafe groundwater status, compare stations as a quality ranking, infer aquifer trends, or classify borewell legality.
- This dataset is not a private borewell register, permit register, extraction-volume inventory, water-pipeline map or groundwater safety certificate.
- The source's measurement datum and sign convention should be confirmed with the data producer before engineering interpretation.

## Validation
- The bundled GeoJSON parses as a FeatureCollection with 21 station features.
- The latest timestamp in the file is 5 November 2026 at 12:00.
- The Flutter dashboard validates the FeatureCollection shape and handles unparseable/missing station timestamps without crashing the list sort.
- No additional database rows or synthetic station readings are created by this feature.
