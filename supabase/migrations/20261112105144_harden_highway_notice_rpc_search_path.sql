-- Security-definer RPCs must not resolve attacker-controlled objects from public.
-- The function schema-qualifies its application tables and auth.uid().
alter function public.publish_highway_work_notice(uuid, text, text, smallint)
  set search_path = '';
