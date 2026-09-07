# Phase K — real end-to-end sync verification checklist

This is a **manual, user-executed** checklist. Everything in this repo has
been verified as far as it can be without a live network path to your
Tailscale-only home server: the schema/RLS/trigger logic was validated
against a native Postgres instance (`../local-sql-validation/`), and every
piece of Dart sync logic (outbox enqueueing, the drainer, the LWW merge
rule, reconciliation) has an automated test using fake remote sources
(`test/data/repositories/*_outbox_test.dart`, `test/data/sync/`). What
**hasn't** been verified — because this sandbox has no route to your
Tailscale network — is GoTrue's actual anonymous-auth behavior, Envoy's
real routing, Storage's actual upload/download path, and Realtime's actual
WebSocket delivery, end to end, against the real deployed stack.

Run through this after completing the deploy runbook in `README.md` and
pointing at least two app instances (two physical devices, or two separate
local runs/user-data directories on one machine — see the note at the
bottom) at the same server. Report back what you see at each step; if
anything doesn't match the expected result, that's the next thing to fix,
not something to work around.

## 0. Before you start

- Both app instances have `.env` pointing at the same
  `SUPABASE_URL`/`SUPABASE_ANON_KEY` for your server.
- You can reach Supabase Studio at `http://<tailscale-name>:8000` to
  inspect Postgres tables directly (SQL Editor → `select * from ...`).
- `jq`, `curl`, and `sqlite3` are available if you want to double check
  anything from the command line instead of Studio/the app UI.

## 1. Anonymous identity is created once and persists

1. Launch app instance A for the first time (fresh install, or a fresh
   local user-data dir). It should open straight to the board with no
   login screen.
2. In Studio → **Authentication → Users**, confirm exactly **one** new
   user appears, with no email/phone, `is_anonymous: true`.
3. Fully close and relaunch instance A.
4. Confirm in Studio that **still only one** user exists — relaunching
   must reuse the persisted session (`SharedPreferencesLocalStorage`), not
   mint a second anonymous identity.

**Expected:** one anonymous user, stable across restarts.
**If it fails:** more than one user after a relaunch means the session
isn't persisting — check that `ensureAnonymousSession()` is actually
finding `client.auth.currentSession` before calling
`signInAnonymously()` again.

## 2. A local change reaches Postgres

1. On instance A, create a board, add a text note, add an image clip, and
   draw one stroke.
2. Within the sync interval (should be near-instant while connected — the
   engine drains on every mutation's outbox write, not just the 45s
   timer), check Studio's **Table Editor** (or `select * from clips`,
   `select * from strokes`, `select * from boards` in the SQL Editor) for
   rows matching what you just created, with `user_id` matching instance
   A's anonymous user id from step 1.

**Expected:** all four rows (board, text clip, image clip, stroke) appear
in Postgres promptly, with correct `user_id`.

## 3. A second device sees it live via Realtime

1. Launch instance B (second device, or a second local run pointed at a
   **different** local user-data directory so it doesn't share instance
   A's Drift database — see the note at the bottom for how to do this on
   one machine).
2. **Important:** instance B will mint its **own, separate** anonymous
   identity the first time it runs (this is the known single-device
   limitation the pairing feature in Phase M addresses) — so before this
   step is meaningful, either wait for Phase M's pairing UI, or manually
   align identities by copying instance A's session out of
   `shared_preferences` into instance B's for this test only. Note in your
   report which approach you used.
3. Once both instances are authenticated as the *same* user, on instance
   A, move a clip or add a new text note.
4. Watch instance B's board — the change should appear within a few
   seconds, with no manual refresh.

**Expected:** the change appears on instance B live, un-refreshed.
**If it fails:** check Studio → Database → Replication that the
`supabase_realtime` publication includes `boards`/`clips`/`strokes`
(should already be set by `0001_init.sql`), and check instance B's app
logs for a realtime subscription/connection error.

## 4. Offline edits queue and push cleanly on reconnect

1. On instance A, disconnect from the network (disable Tailscale, or pull
   the network cable/toggle airplane mode).
2. Make several changes while offline: move a clip, add a text note,
   delete another clip, add a new image.
3. Confirm the changes are all visible locally (they should be — local
   writes never wait on the network).
4. Reconnect the network.
5. Watch for the queued changes to drain (should happen promptly once
   connectivity is detected). Check Studio to confirm every offline
   change landed in Postgres exactly once — no duplicate rows, nothing
   missing.

**Expected:** all offline edits present in Postgres after reconnect, each
exactly once.
**If it fails:** check the local `sync_queue_entries` table
(`sqlite3 <app-data-dir>/hb_clips.sqlite "select * from sync_queue_entries;"`)
for stuck rows with a non-empty `last_error` — that tells you which
specific push failed and why.

## 5. Image (including GIF) round-trips byte-identical

1. On instance A, add an image clip from a regular PNG/JPEG, and
   separately add an animated GIF.
2. Once both have synced (Storage upload completes, `storage_path` is set
   — check via Studio's Storage browser or
   `select id, storage_path from clips where type = 'image';`), on
   instance B (same identity as in step 3), confirm both images appear
   and the GIF **plays/loops**, proving the file's real extension
   survived the round trip (not silently coerced to `.jpg` somewhere).
3. To confirm byte-identical (not just "looks right"): compare
   `sha256sum` of the original source file against the file downloaded
   into instance B's local cache
   (`<app-data-dir>/clips/<clip-id>...`), and/or download the object
   directly from Storage via
   `curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT" "$BASE/storage/v1/object/clip-images/<storage_path>" -o /tmp/check.gif`
   and hash that too.

**Expected:** all three hashes match — source, Storage's stored copy, and
instance B's downloaded cache copy.

## 6. A delete made while another device is offline propagates on reconnect

1. Take instance B offline.
2. On instance A (online), delete a clip that exists on both instances
   (drag to bin, then **Delete Forever**, or just bin it — either is a
   real mutation that should propagate).
3. Reconnect instance B.
4. Confirm instance B's reconciliation pass removes/updates that clip
   locally to match — it should disappear (or move to Binned) without the
   user doing anything.

**Expected:** instance B converges to match Postgres once reconnected,
with no leftover stale local row for the deleted clip.
**If it fails:** this is the reconciliation diff (`SyncEngine.reconcile()`
in `lib/data/sync/sync_engine.dart`) — confirm the row is actually gone
from Postgres first, then check whether the local row was incorrectly
marked `dirty` (which would make reconciliation intentionally keep it,
assuming it's an unpushed local change) — see
`test/data/sync/sync_engine_test.dart` for the exact intended behavior
this step exercises.

## 7. The 30-image cap still rejects server-side

The client already blocks a 31st image locally, so this step needs to
bypass that client-side check to prove the **server-side** trigger from
`0001_init.sql` is a real backstop, not just defense-in-depth on paper:

1. With an authenticated `JWT`/`ANON_KEY` for a user who already has 30
   active image clips (bin doesn't exempt them — binned images still
   count), issue a raw insert directly against PostgREST:
   ```sh
   curl -s -o /dev/null -w "%{http_code}\n" -X POST "$BASE/rest/v1/clips" \
     -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT" \
     -H "Content-Type: application/json" \
     -d '{"id":"<new-uuid>","board_id":"<a-board-id>","user_id":"<uid>","type":"image","x":0,"y":0,"width":100,"height":100}'
   ```
2. Confirm this returns an error (not 201/200), and that the row was **not**
   inserted (`select count(*) from clips where user_id = '<uid>' and type = 'image';`
   still reads 30).

**Expected:** the insert is rejected by the trigger even though it bypassed
every client-side check.

## Note: running two instances from one machine

If you don't have two physical devices handy yet, you can still exercise
most of this on one machine by pointing each run at a different app-data
directory so they get independent local Drift databases (and, until
pairing ships, independent anonymous identities): on Linux this is
typically controlled by `XDG_DATA_HOME`, e.g.
`XDG_DATA_HOME=/tmp/hb_clips_instance_b flutter run -d linux` for the
second instance, leaving the first using its normal default location.

## Reporting back

For each numbered section above, note pass/fail and paste any unexpected
output (error JSON, HTTP status codes, `sync_queue_entries` rows with
`last_error` set, mismatched hashes). A partial run (e.g., only sections
1-2 done so far) is still useful to report — each section is independently
actionable.
