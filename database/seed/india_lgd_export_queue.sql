-- SAMANVAY India-wide LGD import queue
-- Applied to the connected Supabase project on 2026-11-06.
-- This script only queues official exports; it does not fabricate LGD codes or
-- bypass the CAPTCHA used by the public Local Government Directory portal.

with jurisdictions(name,igod_code) as (values
 ('Andaman and Nicobar Islands','AN'),('Andhra Pradesh','AP'),('Arunachal Pradesh','AR'),('Assam','AS'),
 ('Bihar','BR'),('Chandigarh','CH'),('Chhattisgarh','CG'),('Dadra and Nagar Haveli and Daman and Diu','ND'),
 ('Delhi','DL'),('Goa','GA'),('Gujarat','GJ'),('Haryana','HR'),('Himachal Pradesh','HP'),
 ('Jammu and Kashmir','JK'),('Jharkhand','JH'),('Karnataka','KA'),('Kerala','KL'),('Ladakh','LA'),
 ('Lakshadweep','LD'),('Madhya Pradesh','MP'),('Maharashtra','MH'),('Manipur','MN'),('Meghalaya','ML'),
 ('Mizoram','MZ'),('Nagaland','NL'),('Odisha','OD'),('Puducherry','PY'),('Punjab','PB'),
 ('Rajasthan','RJ'),('Sikkim','SK'),('Tamil Nadu','TN'),('Telangana','TS'),('Tripura','TR'),
 ('Uttar Pradesh','UP'),('Uttarakhand','UK'),('West Bengal','WB')
),
requests as (
 select s.id as jurisdiction_state_ut_id,
        'district'::text as unit_type,
        'https://igod.gov.in/sg/'||j.igod_code||'/E042/organizations' as source_url,
        'IGOD state-wise district index; reconcile names and current legal status against official LGD codes. LGD bulk export requires CAPTCHA; no CAPTCHA bypassed and no district rows fabricated.' as notes
 from jurisdictions j join public.india_state_uts s on s.name=j.name
 union all
 select s.id,'urban_local_body'::text,'https://lgdirectory.gov.in/',
        'LGD public download directory: choose Urban Local Body of a State and Download All Entities of State. CAPTCHA verification is required. No CAPTCHA bypassed; no ULB rows or LGD codes fabricated.'
 from jurisdictions j join public.india_state_uts s on s.name=j.name
)
insert into public.india_directory_import_batches
 (jurisdiction_state_ut_id,unit_type,source_url,import_status,rows_received,rows_inserted,rows_rejected,notes)
select r.jurisdiction_state_ut_id,r.unit_type,r.source_url,'awaiting_authorised_export',0,0,0,r.notes
from requests r
where not exists (
 select 1 from public.india_directory_import_batches b
 where b.jurisdiction_state_ut_id=r.jurisdiction_state_ut_id
   and b.unit_type=r.unit_type
   and b.import_status='awaiting_authorised_export'
);

update public.india_data_coverage c
set coverage_status='captcha_required_for_bulk_export',
    national_source_url='https://lgdirectory.gov.in/',
    last_checked_at=now(),
    notes='Official IGOD publishes a State/UT district index. The official LGD portal supplies standard location codes and state-wise district/ULB reports. Bulk exports require CAPTCHA verification. SAMANVAY has queued district and ULB import batches for this jurisdiction. No CAPTCHA bypassed and no LGD codes fabricated.'
from public.india_state_uts s
where c.state_ut_id=s.id and c.data_domain='administrative_directory';
