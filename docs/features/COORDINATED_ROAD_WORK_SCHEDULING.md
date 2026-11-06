# Coordinated Road-Work Scheduling

## Purpose

The schedule board helps authorised staff see planned infrastructure work windows and identify cases scheduled on the same road in the same city during overlapping dates. It complements the existing proximity-based repeated-work advisory: this view compares road-name/city and date windows, while the map advisory compares geographic proximity.

## Scheduling logic

- Uses the existing `planned_start_date` and `planned_end_date` fields on infrastructure cases.
- Detects inclusive date-window overlap when two non-closed cases share a normalised road name and city.
- Excludes rejected and completed cases from active overlap counts.
- Flags missing dates, invalid date windows, overlapping work windows, past-due schedules, current work windows and future schedules.
- Returns the overlapping request numbers for staff review.
- Uses an expression index over normalised city/road names and planned dates.

## Security

The `public.road_work_schedule_advisories` view is created with `security_invoker = true`, so the underlying `excavation_requests` row-level security remains in force. Anonymous/public privileges are revoked; authenticated users receive SELECT only. The view cannot widen a department user's case access.

## Application integration

A coordinated road-work schedule board appears on the staff operations dashboard. It shows each accessible case, road, city, department, planned window, schedule state and overlapping case numbers. Planned dates continue to be edited in the existing infrastructure case form.

## Validation and limitations

- Supabase confirms the view exists with security-invoker semantics and authenticated SELECT is granted while anon SELECT is denied.
- The live project currently returns four accessible schedule rows, with zero overlap flags and zero missing-date flags at the time of validation.
- Overlap matching is based on normalised road name and city, not a certified road-segment GIS identifier. Similar or differently named road segments may require human review.
- The view detects conflicts among rows visible under the current user's RLS permissions. Coordinators/administrators have the broadest overview; a department user sees only cases already assigned and authorised for that account.
- A detected overlap is an advisory, not an automatic rejection or statutory road-closure decision. Staff must coordinate with the road-owning authority and relevant departments.
