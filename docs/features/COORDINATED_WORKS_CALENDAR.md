# Coordinated Works Calendar

## Purpose

The Coordinated Works Calendar gives authenticated SAMANVAY users a single, read-only view of infrastructure cases that have planned start dates. It helps departments and coordinators identify work that may be scheduled near one another, so they can check whether joint execution or a shared road opening is practical.

## Data source and access

- Reads existing `public.excavation_requests` records through the signed-in Supabase client.
- Relies on existing Row Level Security. The page does not broaden table permissions or bypass role-based access.
- Loads up to 2,000 visible records in pages of 250.
- Excludes records without a planned start date from the calendar; those records remain in the case register.
- Performs no database writes and requires no schema migration.

## User features

- Planning windows: next 30 days, next 90 days, or all scheduled dates.
- Filters for case status and infrastructure domain.
- Search across case title, request number, road, city and domain.
- Summary counts for scheduled works, active works and potential schedule overlaps.
- Case cards show planned dates, case status, domain, activity and available location details.

## Potential overlap heuristic

The client flags a pair when both records:
1. Have valid latitude and longitude values.
2. Have planned start dates.
3. Are not in a terminal state (completed, resolved, rejected or cancelled).
4. Have overlapping planned date intervals (a missing end date is treated as the start date).
5. Are within 100 metres according to the Haversine distance calculation.

The pairwise scan is capped at 700 eligible cases to keep mobile rendering responsive. The indicator is explicitly advisory: it is not a verified utility clash, proof of a shared work boundary, excavation permit, safety clearance or approval to combine works. Departments must verify with the responsible asset owners and competent authorities.

## Build integration

Both Android and browser GitHub Actions workflows copy `app/coordinated_work_calendar_page.dart` into the generated Flutter project before dependency installation and analysis.

## Known limitations

- Results are limited to records visible to the authenticated user under existing RLS and to the first 2,000 scheduled/request records fetched.
- The overlap heuristic uses submitted case coordinates, not road-segment geometry or underground utility geometry.
- The 100 m distance and planned-date overlap are screening parameters, not engineering determinations.
- No official road-network or underground-asset dataset is inferred or fabricated.
