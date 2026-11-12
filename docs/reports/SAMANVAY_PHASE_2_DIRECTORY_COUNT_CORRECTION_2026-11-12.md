# SAMANVAY Phase 2 — national directory count correction

**Date:** 12 November 2026  
**Project:** `zhtotivedvkmclerdnlf`  
**Merged application commit:** `9c95e619a69e2f03ae9f672030937e93aa61827`

## Why this correction was required

The India coverage explorer previously loaded at most 1,000 administrative-unit rows and calculated national totals from that partial sample. This silently undercounted the directory. The table also contains historical district-name references from more than one source vintage, so counting all rows inflated district totals.

## Corrected implementation

- Added `public.get_india_administrative_unit_counts()`.
- The function counts distinct, active, non-null LGD-coded units by unit type.
- It is `SECURITY INVOKER`, preserving the caller's row-level security visibility.
- Execute permission is granted to authenticated users only.
- The Flutter explorer now displays aggregate totals and labels the 1,000-row fetch as a diagnostic sample rather than the national count.

## Live RPC result

| Unit type | Distinct active LGD-coded records |
|---|---:|
| District | 784 |
| Sub-district | 7,092 |
| Block | 7,312 |
| **Total** | **15,188** |
| Authority-verified | **0** |

These are directory records carrying LGD codes from the `India LGD Community Mirror 21Oct2026` imports. They are **not certified statutory records**. The source is a community mirror; its 21 October 2026 snapshot date does not itself establish government endorsement or current legal status. All counted rows remain unverified until reconciled against a current authorised Local Government Directory export or competent authority confirmation.

The 733 Datameet 2019 district-name rows are a separate, code-less reference fallback and are deliberately excluded from the aggregate counts. Historical duplicate vintages are also excluded because the RPC counts distinct LGD codes.

## Remaining blockers

- Current authoritative LGD export/API and code reconciliation.
- Complete ULB, ward, gram-panchayat and village records.
- Persisted and QA-reviewed current official boundary polygons.
- Utility-owner-authorised geometry and survey evidence.
- Device-level map, satellite, GPS, role and layer acceptance tests.

No underground utility routes, depths, survey evidence or excavation clearance are inferred from administrative directory records. A missing verified asset remains **data unavailable**, not evidence of an empty subsurface.
