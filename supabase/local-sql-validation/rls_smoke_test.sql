-- Simulates two different authenticated users via PostgREST's own
-- mechanism (the request.jwt.claims GUC), exercising RLS the same way the
-- real REST API would. Grants below mirror what the real self-hosted
-- Postgres image's own init scripts grant to the 'authenticated' role.

do $$ begin
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

grant usage on schema public to authenticated;
grant all on all tables in schema public to authenticated;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant usage on schema storage to authenticated;
grant execute on function storage.foldername(text) to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;

insert into auth.users (id, is_anonymous) values
  ('11111111-1111-1111-1111-111111111111', true),
  ('22222222-2222-2222-2222-222222222222', true);

-- === User 1 creates a board and a clip ===
set role authenticated;
set request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

insert into boards (id, user_id, name) values
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'User 1 Board');

insert into clips (id, board_id, user_id, type, x, y)
select gen_random_uuid(), id, '11111111-1111-1111-1111-111111111111', 'image', 0, 0
from boards where user_id = '11111111-1111-1111-1111-111111111111';

\echo '--- User 1 sees their own board+clip (expect 1/1): ---'
select count(*) as boards_visible from boards;
select count(*) as clips_visible from clips;

reset role;

-- === User 2 should see nothing of User 1's ===
set role authenticated;
set request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

\echo '--- User 2 sees (expect 0/0): ---'
select count(*) as boards_visible from boards;
select count(*) as clips_visible from clips;

reset role;

-- Fetch User 1's board id as superuser into a temp table (a real attacker
-- would need to guess or otherwise learn a UUID; RLS SELECT already hides
-- it above - this isolates whether the WITH CHECK on INSERT independently
-- blocks spoofing). Using a temp table instead of a psql \gset variable
-- here, since \gset substitution inside a later dollar-quoted DO block did
-- not reliably fire in this script (unresolved psql quirk, not worth
-- chasing further - this pattern is simpler and known to work).
create temporary table _t_user1_board as
  select id from boards where user_id = '11111111-1111-1111-1111-111111111111' limit 1;
grant select on _t_user1_board to authenticated;

set role authenticated;
set request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

\echo '--- User 2 inserting a clip onto User 1 board, claiming user_id = User 1 (expect: ERROR, RLS blocks it): ---'
insert into clips (id, board_id, user_id, type, x, y)
select gen_random_uuid(), id, '11111111-1111-1111-1111-111111111111', 'text', 0, 0
from _t_user1_board;

reset role;
drop table if exists _t_user1_board;

-- === 30-image-cap trigger, as User 1 ===
set role authenticated;
set request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

\echo '--- Inserting 30 more image clips (31 total attempted) to trip the cap trigger: ---'
do $$
declare
  bid uuid;
  i int;
begin
  select id into bid from boards where user_id = '11111111-1111-1111-1111-111111111111' limit 1;
  for i in 1..30 loop
    begin
      insert into clips (id, board_id, user_id, type, x, y)
      values (gen_random_uuid(), bid, '11111111-1111-1111-1111-111111111111', 'image', 0, 0);
    exception when others then
      raise notice 'Cap trigger fired at insert #% : %', i, sqlerrm;
      exit;
    end;
  end loop;
end $$;

select count(*) as total_image_clips_for_user1 from clips where type = 'image';

reset role;

-- === Storage RLS: User 1 can only touch clip-images/{their own uid}/... ===
-- Bucket creation is a superuser/service-role action in the real Storage
-- API (end users never create buckets directly), so it's done here as the
-- postgres superuser, before switching into the 'authenticated' role below.
insert into storage.buckets (id, name) values ('clip-images', 'clip-images') on conflict do nothing;

set role authenticated;
set request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

\echo '--- User 1 inserting a storage object under their own uid folder (expect: success): ---'
insert into storage.objects (bucket_id, name, owner)
values ('clip-images', '11111111-1111-1111-1111-111111111111/some-clip/original.png', '11111111-1111-1111-1111-111111111111');

\echo '--- User 1 inserting a storage object under User 2 uid folder (expect: blocked): ---'
do $$
begin
  insert into storage.objects (bucket_id, name, owner)
  values ('clip-images', '22222222-2222-2222-2222-222222222222/some-clip/original.png', '11111111-1111-1111-1111-111111111111');
  raise notice 'FAIL: insert succeeded (storage RLS did not block it)';
exception when others then
  raise notice 'PASS: insert blocked (%)', sqlerrm;
end $$;

reset role;
