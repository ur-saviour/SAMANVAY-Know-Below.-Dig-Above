# India administrative GIS reference layers

**Implementation date:** 11 November 2026  
**Purpose:** Public map context for SAMANVAY. These layers are not a legal boundary certification, an LGD-code directory, or an underground utility inventory.

## Layers

| Layer | API level | Published unit count | Vintage | Publisher/source | Licence |
|---|---|---:|---|---|---|
| State / Union Territory | ADM1 | 36 | 2011 | DataMeet India community; Election Commission of India | Creative Commons Attribution 2.5 India |
| District | ADM2 | 736 | 2021 | Pathways Data Pvt. Ltd.; Local Government Directory source attribution | Open Data Commons Open Database License 1.0 |

The source metadata is read from the geoBoundaries API when the authenticated map requests the layer. The Edge Function only proxies the two allow-listed India reference levels, validates the country and level, limits payload size and feature count, and caches successful responses in its runtime for six hours. The map displays the returned source, vintage and licence metadata.

## Attribution

The product must acknowledge geoBoundaries and the original source/licence returned with each boundary dataset. See https://www.geoboundaries.org/api.html. The data are distributed through the gbOpen API, but the licence of each individual geography must be read from its metadata; do not assume every geography has the same licence.

## Data governance and limitations

- The State/UT layer is based on a 2011 vintage. It is suitable for map orientation and reference display, not as a current statutory boundary decision.
- The district layer is a 2021 vintage and includes 736 mapped units. It is not a substitute for the current Local Government Directory export or official LGD codes.
- The administrative-unit hierarchy table remains a separate data product. Districts, sub-districts, blocks, ULBs, panchayats, villages and wards must be imported from an authorised current LGD export and reconciled by LGD code.
- Boundary overlays never imply the availability of utility data in a jurisdiction.
- No buried water, sewer, stormwater, electricity, telecom or gas routes are inferred from surface maps or administrative boundaries.
- Exact underground utility geometry must remain restricted to the owning authority and its authorised staff. Public GIS may show only approved generalised coverage.
- A missing, stale or unverified layer never means that no underground utility exists and is never excavation clearance.
- For statutory or engineering decisions, use the competent government authority's currently certified boundary and records.

## Current operational blockers

The live Supabase audit on 11 November 2026 found:
- 36 State/UT master entries and 396 coverage metadata rows.
- 0 imported LGD administrative-unit records.
- 0 registered underground-asset geometry records and 0 registered survey-evidence records.
- 11 utility source-registry rows and 125 utility layer-catalogue rows; these are discovery metadata, not live asset geometry.

The map feature therefore completes public-facing national reference geography, not the operational asset-owner GIS dataset. Utility geometry completion still requires authorised source handover, validation, and independent verification from each relevant custodian.
