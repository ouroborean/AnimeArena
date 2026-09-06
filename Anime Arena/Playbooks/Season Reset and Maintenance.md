---
tags: [area/playbook, type/howto]
---

# Season Reset and Maintenance

Two live-ops procedures that both run **through the server**, never around it. The reason is the same
in both cases: the server holds authoritative in-memory state that will happily overwrite anything
you do behind its back.

---

## Part 1 — Season reset

### Why you must NOT write a script over `ausers/*.dat`

This is the whole lesson. The obvious approach — glob `ausers/*.dat`, zero the wins/losses/rating
fields, write them back — **appears to work and then silently undoes itself**.

`initialize_players()` loads *every* account into the in-memory `players` cache at boot. That cache is
what fresh-login session creation and `resave_player` read from. So:

1. Your script edits `ausers/Wimbly.dat` on disk. Looks perfect.
2. Wimbly logs in. The session is built from `players["Wimbly"]` — the **pre-edit** object still in
   memory.
3. Anything at all triggers `resave_player`. The stale in-memory record is written back over your
   edit.

The comment above the implementation says it directly (`components/server_connection.gd:537`):

> Editing the .dat files under a running server is therefore silently reverted the moment an edited
> player logs in or is resaved for any other reason. Doing it here mutates the live objects AND the
> files in one pass, so there is no window where the two disagree.

> [!danger] The cache overwrites in BOTH directions
> It is not only that your edits get reverted. A resave from a longer-lived in-memory `Player` can
> also write progress the file on disk never had. Observed 2026-07-29: after an `ausers/` restore,
> `Suffering.dat` and `Wimbly.dat` came back with ~12 more matches, more AP, and a different
> rating/tier than a snapshot taken earlier the same session — with mtimes minutes *after* the
> restore. Consequences:
> - Stop the server and **confirm no `godot` process survives** before touching `ausers/` at all.
> - A mid-session snapshot is **not** ground truth. When disk and snapshot disagree, compare
>   wins/losses/AP and mtimes and keep the **fuller** state. Never blind-restore a snapshot over live
>   saves.

A file script is only safe with the server **fully stopped** — and even then the supported op is
better, because it stays correct as the schema moves.

### The supported path: `admin_season_reset`

A JSON-gateway message handled at `components/server_connection.gd:969`, admin-only, with no single
target (which is why it is separate from `admin_modify_player`).

```json
{"type": "admin_season_reset", "dry_run": true}
{"type": "admin_season_reset", "dry_run": false, "confirm": "RESET SEASON"}
```

Three independent safety layers, in order:

| Layer | Behaviour |
|---|---|
| **Dry run is the default** | `bool(msg.get("dry_run", true))` — a caller who sends nothing but the message type gets a preview, never a wipe |
| **Confirm phrase** | `SEASON_RESET_CONFIRM := "RESET SEASON"`; any other value is refused with a note |
| **Mandatory backup** | `_backup_accounts()` writes a timestamped `ausers_backup_<stamp>/`; **a failed backup aborts the reset** — "Backup failed — nothing was reset." |

Then, per account (`_season_reset`, line 571):

```gdscript
_reset_player_record(target)
resave_player(target)
# Push the zeroed record to anyone online so their profile does not sit stale until relog.
if uname in sessions and sessions[uname].peer_id in peer_map:
	send_player_update(sessions[uname].peer_id)
```

It reuses the **same** `_reset_player_record` helper (line 516) that the per-player admin
"Reset W/L Record" op and the self-service reset use, so it cannot drift from the schema:

```gdscript
target.rank.wins = 0
target.rank.losses = 0
target.rank.streak = 0
target.rank._ranked_streak = 0
target.rank._rp = 0
# rank/rank_tier are derived from rating (Rank.tier_for_rating), so zeroing the rating IS the
# demotion back to Iron 1 — there is no stored tier to reset.
target.rank.set_values(0, 0, 0, 0)
```

> [!info] There is no stored tier
> Iron 1 … Grandmaster is *derived* from rating via `Rank.tier_for_rating`. Zeroing the rating **is**
> the demotion. Do not go looking for a `rank_tier` field to clear. See
> [[Matchmaking and the Ladder]].

### What is and is not touched

| Reset | Preserved |
|---|---|
| `rank.wins`, `rank.losses` | AP |
| `rank.streak`, `rank._ranked_streak` | Unlocks (character/cosmetic tokens) |
| `rank._rp` | Mastery / `character_progress` |
| rating → 0 (⇒ Iron 1) | Bounties |
| | Campaign progress |
| | `match_history` |

### Running it

From the admin panel (FAB → tabbed modal → **🏆 Ranked Season**, `webclient/app/app.js:4013`):

- **"Preview Season Reset"** — a single click, sends `{dry_run: true}`, changes nothing. It also
  disarms the wipe button.
- **"Reset Season"** — a separately-armed two-tap button (`arm()` helper, 8-second auto-disarm) that
  warns *"Tap again to WIPE every player's W/L and rating"*, then sends
  `{dry_run: false, confirm: "RESET SEASON"}`.

The reply is `admin_season_reset_result`, carrying `note`, `accounts`, `reset`, `failed` and the
`backup` directory name; the client toasts the note and refreshes the player list on a real run.

Dry-run note format:

> Would reset N account(s); M currently carry a record. Re-send with confirm="RESET SEASON" to apply.

### Verifying it safely

Verified end-to-end 2026-07-29 against a **sandbox** `ausers/`: non-admin refused, dry run changed
nothing, wrong confirm phrase refused, real run reset 6/6 with AP and characters preserved, and the
backup held the originals.

The harness rule that made that safe:

> [!warning] Never point a live harness at the real accounts directory
> Stage a synthetic `ausers/` (including an admin name — `ADMIN_USERNAMES` is `Cheshire` /
> `IsaacTheEmperor`), fingerprint the real directory first (sha256 per file), restore it afterwards
> and **re-verify the hashes byte-identical**.
>
> Live harnesses also leave a `ZZ_*` registration behind — delete the ones **this session** created.
> `ausers/` already holds ~54 `zz*`/`ZZ_*` throwaway accounts from past harnesses. They are expected;
> do not "clean" them and do not count them as damage.

`ausers_backup_*/` contains `pass_hash` values and is gitignored. Do not move those directories
anywhere shareable.

---

## Part 2 — Update / maintenance

Three admin steps, all `admin_maintenance` with an `action`
(`components/server_connection.gd:932`), driven from the **🚧 Update / Maintenance** section of the
admin panel:

```
warn  →  eject  →  (operator stops the process and starts the new build)
                                    ↑ cancel backs out of either step
```

> [!info] All state is in-memory, and the restart IS the reset
> A freshly booted process has an empty `maintenance` dictionary and a brand-new `boot_id` — exactly
> the state a waiting client is polling for. There is nothing to remember to switch off afterwards.

### Step 1 — `warn`

```json
{"type": "admin_maintenance", "action": "warn", "message": "...", "seconds": 600}
```

Sets `maintenance = {message, locked: false, seconds}` and broadcasts `maintenance_notice`.
`seconds` is clamped to `0..7200`; the message is run through `_clean_text(…, 200)` like any other
admin-authored text that lands on every player's screen.

**A warning does not lock logins.** Players keep playing until the eject
(`_maintenance_locked()` reads `maintenance.locked`).

> [!warning] A warning must not be a one-way trap
> `_process_login` sends the current maintenance state on **every** login — `maintenance_notice` when
> warning, `maintenance_cleared` when there is none. Without that, late joiners never hear about the
> update and a banner left over from before a restart would never clear itself.

### Step 2 — `eject`

```json
{"type": "admin_maintenance", "action": "eject", "message": "..."}
```

Sets `maintenance = {message, locked: true}` and then — **before** the broadcast, so no match can
resolve against a player already on their way to the login screen — runs `_maintenance_stand_down()`
(line 389):

```gdscript
func _maintenance_stand_down() -> Array:
	var doomed := []
	for uname in sessions:
		var m = sessions[uname].current_match
		if m != null and is_instance_valid(m) and not doomed.has(m):
			doomed.append(m)
	var dequeued: int = queued_players.size() + private_queue.size()
	for rank in ranked_queue:
		for tier in ranked_queue[rank]:
			dequeued += ranked_queue[rank][tier].size()
	for pid in peer_map.keys():
		_release_queues(pid)
	for m in doomed:
		m.cancel_match()
	return [doomed.size(), dequeued]
```

> [!danger] The eject must stand the server DOWN, not just broadcast
> - **Cancel every live match** (`Match.cancel_match`, a no-contest — no W/L, no rating, no AP).
>   Without it, an ejected player simply stops taking turns and the **AFK timer forfeits them a real
>   ranked loss**; anyone inside their 120s reconnect grace is additionally surrendered by
>   `wipe_session` when the login lock refuses their re-login.
> - **Empty every queue**, or the matchmaker — and the ranked bot fallback — seats somebody into a
>   brand-new match seconds before the process dies.

> [!danger] Never eject the admin
> The broadcast is `json_gateway.broadcast_except(_admin_peer_ids(), …)`. An admin thrown to the login
> screen loses the admin panel, and with it the **Cancel** button — ejecting yourself makes the step
> unreversible.
>
> **Watch the id namespaces.** `sessions[*].peer_id` is a LOGICAL id (`JSON_PEER_BASE + gateway id`);
> `json_gateway` keys its peers by the raw gateway id. Excluding the logical id matches nothing and
> quietly ejects the admin anyway. `_admin_peer_ids()` (line 370) converts with `_json_local()`.

The client's own side (`leaveForMaintenance`, `webclient/app/app.js:892`) **closes its socket**. Left
open, the `ServerSession` stays ONLINE and a later Cancel could not let the player back in — their own
stale session would reject the re-login. Closing also makes `server_status` the single channel for
both outcomes: same boot_id + unlocked = cancelled, different boot_id = relaunched.

The admin gets back `maintenance_state {phase:"ejected", matches_cancelled, dequeued}` — the
confirmation line to read before pulling the process down.

### Step 3 — restart, and how clients notice

```gdscript
var boot_id: String = str(int(Time.get_unix_time_from_system())) + "_" + str(randi())
```

`boot_id` regenerates on **every process start**. It is the reload signal, and it has to be, because a
reconnect alone cannot distinguish a relaunched server from the old one that has not died yet. Time
alone would suffice (restarts are seconds apart at minimum); the random suffix makes a same-second
restart safe too.

The client compares it in two places (`webclient/app/app.js:306`):

```js
function noteBootId(id) {
  if (!id) return false;
  if (!S.bootId) { S.bootId = id; return false; }   // never reload on first sight
  if (S.bootId === id) return false;
  S.bootId = id;
  bustedReload();
  return true;
}
```

- via the **pre-auth `server_status`** message the ejected client polls for;
- via `noteBootId()` on **any frame carrying a boot_id**, so a client that was disconnected during the
  eject — and therefore never entered the ejected phase — still reloads instead of running the
  previous frontend.

> [!warning] The reload must be cache-busted
> It goes to a `?u=<now>` URL (`bustedReload`). `index.html` cache-busts its own assets, but the HTML
> itself can be cached, and a plain `location.reload()` would just serve the stale copy.

### Step 4 — `cancel`

```json
{"type": "admin_maintenance", "action": "cancel"}
```

Clears `maintenance` and broadcasts `maintenance_cleared`. Handles both "we changed our mind after the
warning" and "we changed our mind after the eject" — in the latter case the ejected clients see the
same boot_id plus `maintenance === false` on `server_status` and are told
*"Update cancelled — you can log in again."*

### Deploying the new build

```powershell
.\deploy.ps1                 # build-pages-deploy + wrangler pages deploy + scp the server binary
.\deploy.ps1 -SkipServer     # web client only
.\deploy.ps1 -SkipFrontend   # server binary only
.\deploy.ps1 -CheckKey       # test the SSH deploy key, print install steps on failure
```

> [!warning] `deploy.ps1` does NOT build the server binary
> Export `web_anime_server.x86_64` from Godot **first**. The script prints the binary's age in minutes
> so you can catch a stale export. It also warns that an uploaded binary is inert until the running
> process is restarted (`-RestartServer` runs `$RestartCmd`, which ships as a deliberate placeholder
> that errors out until you set it).

See [[Data Files and the Deploy Mirror]] for what `build-pages-deploy.ps1` assembles.

---

## Run order for a normal update

1. Export the server binary from Godot.
2. Admin panel → 🚧 Update / Maintenance → **Announce Update** (message + minutes).
3. Wait out the announced window.
4. **Eject All to Login** (two-tap arm). Read back `matches_cancelled` / `dequeued`.
5. `.\deploy.ps1` — front-end to Pages, binary over scp.
6. Stop the server process on the box; start the new build.
7. Watch a browser tab: it should reload itself to a `?u=…` URL once the new process answers
   `server_status` with a different `boot_id`.

A season reset, if it is part of the same maintenance window, goes **after** the restart and while
nobody is queued — Preview first, then the armed wipe.

---

## Checklist

**Season reset**

- [ ] Nobody mid-match (run it inside a maintenance window, or accept the resave race)
- [ ] Preview run first; the account count looks right
- [ ] Real run used the exact phrase `RESET SEASON`
- [ ] `ausers_backup_<stamp>/` exists and is non-empty
- [ ] Spot-check one account: W/L and rating zeroed, **AP and unlocks intact**
- [ ] No `ausers/*.dat` was hand-edited at any point

**Maintenance**

- [ ] Announce ran and players saw the banner
- [ ] Eject reported the matches it cancelled and the players it dequeued
- [ ] The admin session still has the admin panel (i.e. was not ejected)
- [ ] New binary exported **before** `deploy.ps1` ran
- [ ] Process actually restarted (a fresh `boot_id` in the logs)
- [ ] A logged-out browser tab auto-reloaded to a `?u=` URL

---

## Related

[[Admin and Live Ops]] · [[Matchmaking and the Ladder]] · [[Server Authority Model]] ·
[[Data Files and the Deploy Mirror]] · [[Hard Rules and Guardrails]] · [[Verification Playbook]] ·
[[Web Client Architecture]] · [[Anime Arena]]
