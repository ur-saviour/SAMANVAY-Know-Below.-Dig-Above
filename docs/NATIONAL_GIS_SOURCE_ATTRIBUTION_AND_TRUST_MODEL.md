# SAMANVAY national GIS source attribution and trust model

## Purpose

This document defines the display and operational-use boundaries for open geospatial reference data and owner-authorised underground infrastructure records. Adding an open building or administrative reference layer does **not** establish the presence, absence, route, depth, condition or clearance status of underground utilities.

## Source and licence register

| Source | Intended use | Licence / attribution requirement | Operational boundary |
|---|---|---|---|
| OpenStreetMap | Road network, place search and other mapped context | Open Database Licence (ODbL); display OpenStreetMap contributor attribution and make the licence available | Community-mapped context; completeness and positional accuracy vary |
| Open Buildings | Building footprints where a suitable country extract and licence choice are documented | Google Research describes CC BY 4.0 or ODbL 1.0 licensing; retain the selected licence and required attribution with each import | Building footprints only; not a utility inventory or statutory building approval |
| GHSL | Gridded settlement, population and built-up context | CC BY 4.0; cite the relevant GHSL product/release and acknowledge the European Commission Joint Research Centre | Regional context and analysis; not parcel-precise or utility geometry |
| OpenBuildingMap | Optional country-level building-footprint reference, with its dataset provenance retained | Project dataset states ODbL 1.0; retain source identifiers and attribution | Building context only; source lineage may combine other footprint products |

### Required source metadata

Every imported reference dataset must retain, at minimum: source title, publisher, source URL, dataset/release date, retrieval date, spatial coverage, coordinate reference system, licence identifier and attribution text, import job identifier, validation status, and known limitations. The application must show the source date/freshness and distinguish missing metadata from verified freshness.

Do not import a dataset where the applicable licence, source release or provenance cannot be established. Do not remove upstream attribution. Do not derive building geometry from Google Street View.

## GIS trust classes

1. **Verified owner-authorised utility geometry** — submitted by the asset-owning authority or an explicitly authorised custodian, with documented authority, source and review evidence. Exact geometry is restricted to authorised owner-department roles under existing server-side controls. It may be used by the authorised conflict-screening workflow subject to its own limitations and mandatory field/owner confirmation.
2. **Generalised aggregate coverage** — an intentionally coarsened coverage representation. It may communicate that a service domain has some recorded coverage in an area, but it must not expose or imply exact routes, access points or depths. It is not eligible for excavation clearance or exact proximity determinations.
3. **Context-only, estimated or illustrative reference** — open building footprints, administrative boundaries, gridded settlement data, incomplete observations and any schematic rendering. These layers must carry an explicit context/estimated label and must be excluded from utility clash and clearance decisions.

Synthetic routes, sample depths, fake clash markers and fabricated authority records must never be inserted into production data. An empty or inaccessible layer is **unknown**, not proof that no infrastructure exists.

## Freshness, confidence and display

- Show the source/provider and source date, retrieval/import timestamp, verification status and confidence/limitations wherever a layer is enabled.
- Distinguish source freshness from positional accuracy and authority verification; they are separate dimensions.
- Preserve UNVERIFIED status until the owner-authorised review process records a supported verification outcome.
- Do not infer a statutory approval, no-dig restriction or excavation clearance from map imagery, building footprints, aggregate coverage or AI suggestions.
- Retain source attribution in the map UI and dataset metadata. For OSM-based maps, provide visible OpenStreetMap contributor attribution and a link to the ODbL information.

## Current repository data boundary

The current bundled Coimbatore ward boundary file is an administrative reference, not a statutory boundary certification and not an underground utility layer. The current groundwater snapshot is a limited telemetry reference, not a national groundwater inventory. National authority directories and data-readiness records are acquisition/governance material; they do not mean that all state, district, municipal or utility GIS data has been received, licensed, validated or imported.

## Official licence references

- OpenStreetMap copyright and ODbL: https://www.openstreetmap.org/copyright
- OSM Foundation attribution guidance: https://osmfoundation.org/wiki/Attribution_Guidelines
- Google Research Open Buildings: https://sites.research.google/gr/open-buildings/
- GHSL data and licence information: https://human-settlement.emergency.copernicus.eu/ghs_faq.php
- OpenBuildingMap: https://openbuildingmap.org/

This register is a project governance specification. It is not a claim that these datasets have already been downloaded or ingested into SAMANVAY.
