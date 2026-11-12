# SAMANVAY — Phase 6 Administrative Hierarchy Integrity Audit

**Audit date:** 13 November 2026  
**Supabase project:** `zhtotivedvkmclerdnlf`  
**Repository branch:** `feature/alpha-03-integrated-platform`

## Scope

Read-only integrity audit of `public.india_administrative_units`, `public.india_state_uts`, `public.india_directory_import_batches`, `public.india_data_coverage`, `gis.utility_layer_catalog` and `gis.restricted_utility_source_registry`.

No rows were inserted, updated or deleted during this audit.

## Current inventory

| Unit type | Rows | Source / vintage | LGD code condition | Verification |
|---|---:|---|---|---|
| District (all vintages) | 2,251 | Includes 2019 DataMeet references and 21 Oct 2026 LGD community mirror | 784 distinct LGD codes; 1,467 rows have no LGD code | All unverified |
| Sub-district | 7,092 | LGD community mirror, 21 Oct 2026 | 7,092 distinct codes | All unverified |
| Block | 7,312 | LGD community mirror, 21 Oct 2026 | 7,312 distinct codes | All unverified |
| Urban local body | 5,050 | Third-party India Cities & Administrative Data API mirror, 23 Sep 2026 | 5,050 distinct codes | All unverified |

Other directory figures: 36 State/UT parent rows; 396 data-coverage records across 11 domains; 67 official-source entries; 9 national authority references; 125 utility layer contracts; and 11 restricted utility service-layer metadata rows.

Operational readiness remains zero: no coverage row, utility contract or restricted service layer is enabled for operational utility use; no verified underground utility asset or registered survey-evidence rows exist.

## Integrity checks

| Check | Result | Interpretation |
|---|---:|---|
| Duplicate non-null LGD codes within unit type | 0 | No duplicate codes found by the audited grouping |
| Orphaned non-null parent IDs | 0 | Every populated parent_unit_id resolves to an existing administrative-unit row |
| Blocks with parent district | 7,312 / 7,312 | All block rows are linked to a district record |
| Sub-districts with parent district | 7,092 / 7,092 | All sub-district rows are linked to a district record |
| Units with State/UT association | 100% | No state_ut_id is missing |
| Verified hierarchy rows | 0 | All imported rows remain imported_unverified |

### Known structural gaps

1. **ULB-to-district links:** 5,050 ULB mirror rows have a State/UT association and unique LGD code, but `parent_unit_id` is null. The pinned source JSON did not contain `districtCode` or `districtName`. No district parent is inferred. Obtain an authoritative LGD ULB export or a source that explicitly maps each ULB to a district before adding parent links.
2. **Historical district references:** 1,467 rows are from names-only historical boundary datasets and have no LGD code. Keep them separate from the 784 distinct LGD-coded district records. Do not count all 2,251 as current districts.
3. **State links:** District and ULB records have `state_ut_id` links directly to `india_state_uts`; they do not require state records to be represented as rows in `india_administrative_units`. Therefore a null `parent_unit_id` on those row types is not itself an orphan.
4. **Authority status:** All imported hierarchy rows remain unverified. Structural integrity does not certify current legal boundaries, jurisdiction, ULB existence, statutory ward boundaries or authority provenance.
5. **Ward level:** No LGD ward rows are imported. The bundled 100-ward Coimbatore 2024 polygons are a separate non-statutory navigation reference.

## Import provenance

- District, sub-district and block community mirror source snapshot: 21 October 2026; the mirror was ingested 29 October 2026.
- ULB source: `indian-cities-data` repository file pinned to Git commit `4d9a402258b6dbb5f6aff3f61a67483c42da6771`; snapshot date 23 September 2026.
- ULB import batch: 5,050 received, 5,050 inserted, 0 rejected. The batch notes explicitly state that the source has no district mapping and that the imported rows remain unverified.
- LGD district import batch: 784 received, 784 inserted, 0 rejected.
- LGD sub-district import batch: 7,092 received, 7,092 inserted, 0 rejected.
- LGD block import batch: 7,342 received, 7,312 inserted, 30 rejected. The 30 rejected entries were the records associated with 15 duplicated source LGD block codes; no arbitrary duplicate winner was selected.

## Recommended next Phase 6 implementation

1. Obtain state-wise official LGD exports through the normal authorised portal process; do not automate or bypass CAPTCHA.
2. Reconcile the 784 LGD-coded districts with the current official export and preserve renamed, split, merged and retired codes through effective dates.
3. Acquire an authorised ULB-to-district mapping and import it only after validating the ULB and district LGD codes.
4. Obtain ward-level LGD exports and keep them separate from the Coimbatore 2024 polygon reference.
5. Preserve original import batches and rerun this audit after each new official batch.
6. Only after the hierarchy is authority-verified should it be used for official assignment, statutory workflow or operational coverage claims.

**Conclusion:** the current reference hierarchy is structurally consistent for its imported parent links and has no duplicate LGD codes in the audited rows, but it is not yet authority-verified or complete at ward level. ULB-to-district mapping and official reconciliation remain open.
