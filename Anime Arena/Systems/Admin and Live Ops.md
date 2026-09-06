---
tags: [area/systems, type/reference]
---

# Admin and Live Ops

Everything an operator can do to the running server goes through **admin message handlers on the
JSON gateway** in `components/server_connection.gd`. There is no separate admin service, no shell
tooling, and — critically — no supported path that edits account files under a live process.

## Who is an admin

```gdscript
const ADMIN_USERNAMES: Array = ["Cheshire", "IsaacTheEmperor"]

func _is_admin(username) -> bool:
	return username != null and str(username) in ADMIN_USERNAMES
```
(`server_connection.gd:336`, `:405`)

> [!danger] The exact-case match is deliberate
> The account namespace is `ausers/<name>.dat`, and that filesystem is case-sensitive on the Linux
> production host. A case-insensitive check here would be a **privilege-escalation hole**: anyone
> could register `cheshire` — a distinct account with their own password — and inherit admin.
> `_collides_with_admin_name` (`:415`) is the defence in depth: registration rejects any
> case-variant of a reserved admin name.
>
> Side effect worth knowing when building a test harness: **admin-whitelisted usernames cannot be
> registered**. To make a test admin, register a `ZZ_`-prefixed name while unlisted, then whitelist
> it and restart.

Every admin handler **re-checks authority server-side**. The client's UI gating is convenience only
and must never be trusted — the pattern is repeated verbatim in each `match` arm:

```gdscript
var xa = get_player(logical_peer)
if xa == null or not _is_admin(xa.username):
	json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
else:
	...
```

## The handler surface

| message | what it does | file:line |
|---|---|---|
| `admin_announce` | broadcast a scrolling marquee to every client (500-char cap) | `:884` |
| `admin_close_nexus_round` | remove the top N Nexus characters, halve every remaining bucket | `:900` |
| `admin_scale_nexus_ap` | multiply every Nexus bucket by a factor | `:915` |
| `admin_maintenance` | `warn` / `eject` / `cancel` — the update flow | `:932` |
| `admin_season_reset` | ladder rollover, dry-run by default | `:969` |
| `admin_list_players` | snapshot of every connected session + status/stats | `:983` |
| `admin_training_status` | trainer status file, Elo ledger, live policy generation, replays | `:993` |
| `admin_get_bot_tuning` / `admin_set_bot_tuning` | read/write `bot_tuning.json` | `:1026`, `:1032` |
| `admin_fetch_training_replay` | stream a `training/replays/*.replay` to the client viewer | `:1183` |
| `admin_modify_player` | `grant_ap` / `reset_record` / `add_unlock` / `remove_unlock` / `mute` / `unmute` | `:1204` |
| `admin_character_stats` | per-character usage/win aggregates, optionally date-windowed | `:1262` |
| `admin_toggle_global_chat` | global-chat kill switch (in-memory) | `:1336` |
| `admin_toggle_creator` | Character Creator kill switch (**persisted**, gates real behaviour) | `:1350` |

`_admin_get_target(uname)` (`:425`) is the shared target resolver: live session object first (so
edits reflect mid-session), then the in-memory account cache, then a disk load. It rejects `/`, `\`
and `..` up front, because the username flows into `ausers/<name>.dat`.

The client renders all of it as tabs on an admin panel FAB: **Players**, **Char Usage**, **Nexus**,
**Training** (`webclient/app/app.js:4493-4496`). See [[Web Client Architecture]].

> [!warning] `send_queued`, not `send`, for big admin payloads
> `admin_training_status` uses `json_gateway.send_queued` and caps its lists (24 replays, 40 Elo
> rows). A plain `send()` **silently drops** the frame once the peer's 64KB WebSocket buffer backs
> up, and a long training run accumulates hundreds of replays.

## The update / maintenance flow

Three steps, driven from the 🚧 Update / Maintenance section of the admin panel:
**warn → eject → restart**. `admin_maintenance` takes `action ∈ {warn, eject, cancel}`.

```gdscript
"warn":   maintenance = {"message": mt_msg, "locked": false, "seconds": mt_secs}
          json_gateway.broadcast({"type": "maintenance_notice", ...})
"eject":  maintenance = {"message": mt_msg, "locked": true}
          var stood_down = _maintenance_stand_down()
          json_gateway.broadcast_except(_admin_peer_ids(), {"type": "maintenance_eject", ...})
"cancel": maintenance = {}
          json_gateway.broadcast({"type": "maintenance_cleared", "boot_id": boot_id})
```

All maintenance state is **in-memory on purpose, and the restart IS the reset**. A freshly booted
process has an empty `maintenance` and a brand-new `boot_id` — exactly the state an ejected client
is polling for. There is nothing to remember to switch off afterwards.

A bare **warn does not lock logins**. Players keep playing until the eject
(`_maintenance_locked()` reads `maintenance.locked`).

### `boot_id` is the reload signal

```gdscript
var boot_id: String = str(int(Time.get_unix_time_from_system())) + "_" + str(randi())
```
(`:355`)

A reconnect alone cannot tell a relaunched server from the old one that has not died yet, so the
client compares boot ids — via the pre-auth `server_status` message, and via `noteBootId()` on any
frame that carries one, so a client disconnected *during* the eject still reloads instead of running
the previous frontend. Time alone would suffice (restarts are seconds apart at minimum) but the
random suffix makes a same-second restart safe too.

> [!tip] Reload to `?u=<now>`, never `location.reload()`
> `index.html` cache-busts its own assets, but the HTML itself can be cached — and
> `location.reload()` would serve it straight from cache, leaving the user on the old frontend.

### The eject must stand the server down

The single most important thing about this feature: **broadcasting is not enough.**

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
(`:389`)

- **Cancel every live match** as a no-contest (`Match.cancel_match` — no W/L, no rating, no AP).
  Without this an ejected player simply stops taking turns and the **AFK timer forfeits them a real
  ladder loss** (see [[Matchmaking and the Ladder]]); and anyone inside their 120s reconnect grace
  is surrendered by `wipe_session` when the login lock refuses their re-login.
- **Empty every queue**, or the matchmaker — and the ranked bot fallback — seats somebody into a
  brand-new match seconds before the process dies.

It runs **before** the broadcast, so no match can resolve against a player who is already on their
way to the login screen.

> [!danger] Never eject the admin who triggered it
> `broadcast_except(_admin_peer_ids(), …)`. An admin thrown to the login screen loses the admin
> panel — and with it the Cancel button — making the step unreversible.
>
> **Watch the id namespaces.** `sessions[*].peer_id` is a *logical* id (`JSON_PEER_BASE + gateway
> id`) while `json_gateway` keys peers by the **raw gateway id**. Excluding the logical id matches
> nothing and silently ejects the admin anyway, which is exactly what it did before `_json_local()`
> was applied inside `_admin_peer_ids()` (`:370`).

### Two supporting client behaviours

- **The client closes its own socket on eject** (`leaveForMaintenance`). Left open, the
  `ServerSession` stays ONLINE and a later Cancel could not let the player back in — their own stale
  session would reject the re-login. Closing also makes `server_status` the single channel for both
  outcomes: *same boot_id + unlocked* = cancelled, *different boot_id* = relaunched.
- **A warning must not be a one-way trap.** `_process_login` sends the current maintenance state on
  **every** login — `maintenance_notice` when warning, `maintenance_cleared` when there is none — so
  late joiners hear about it and a banner left over from before a restart clears itself.

> [!warning] CSS gotcha from building the banner
> A `.aa-maint--slim` class rule lost to the base `.aa-maint` even at doubled specificity, and so
> did a plain inline style; only `style.setProperty(…, "important")` won. A `transition` on
> `min-height` also never settled — the bar stayed at full height indefinitely. The collapse is
> therefore instant and set at important priority.

## Season reset

> [!danger] Never reset the ladder by editing `ausers/*.dat` while the server runs
> `initialize_players()` loads **every** account into the `players` cache at boot, and that cache is
> what fresh-login session creation and `resave_player` read from. A file edit is silently reverted
> the moment that player logs in or is resaved for any reason. A file script is only safe with the
> server fully stopped.

The supported path is `admin_season_reset` → `_season_reset(dry_run, confirm)`
(`server_connection.gd:571`), which mutates the live `Player` objects **and** the files in one pass,
so there is no window where the two disagree.

- **Reuses `_reset_player_record`** (`:516`), the same helper the per-player admin op uses, so it
  stays correct as the schema moves. That helper zeroes `wins`/`losses`/`streak`/`_ranked_streak`/
  `_rp` and calls `rank.set_values(0,0,0,0)`. Because `rank`/`rank_tier` are derived from rating,
  **zeroing the rating IS the demotion to Iron 1** — there is no stored tier to reset. See
  [[Matchmaking and the Ladder]].
- **Untouched:** AP, unlocks, mastery / `character_progress`, bounties, campaign progress,
  `match_history`.
- **Defaults to a dry run.** A real run needs `dry_run: false` **and**
  `confirm: "RESET SEASON"` (`SEASON_RESET_CONFIRM`, `:542`). A caller who sends nothing but the
  message type gets a preview, never a wipe.
- **Takes its own timestamped `ausers_backup_<stamp>/` first and aborts if the backup fails**
  (`_backup_accounts`, `:546` — returns `""` on any failure, and `_season_reset` bails). Those dirs
  contain `pass_hash`; they are gitignored as `ausers_backup_*/`.
- **Pushes `send_player_update`** to anyone online so profiles don't sit stale until relog.

Admin panel: "Preview Season Reset" (safe) plus a two-tap "Reset Season" under 🏆 Ranked Season.

> [!danger] Swapping `ausers/` under a running server is unsafe in BOTH directions
> The cache does not only revert your file edits — a resave from a longer-lived in-memory `Player`
> can also **write progress the file on disk never had**. Observed 2026-07-29: two account files
> came back with ~12 more matches, more AP and a different rating than a snapshot taken earlier the
> same session, with mtimes minutes after a restore. Therefore:
>
> - Stop the server and **confirm no `godot` process survives** before touching `ausers/`.
> - A mid-session snapshot is **not** ground truth. When disk and snapshot disagree, compare
>   wins/losses/AP and mtimes and keep the **fuller** state — never blind-restore a snapshot over
>   live saves.
> - `ausers/` already holds ~54 `zz*`/`ZZ_*` throwaway accounts from past harnesses. They are
>   expected; do not "clean" them and do not count them as damage. Only remove accounts *this
>   session* created.

## Character usage stats

`components/stats_db.gd` (`StatsDB`, a SQLite `stats.db` with WAL and parameterized upserts) is the
queryable source of truth, superseding the old flat `stats/<char>.stats` files (whose only reader had
zero callers). The flat files and `stats/matches/*.json` logs are kept as a raw audit trail.

Recording happens in `handle_server_match_ended` (`:3529-3543`) and counts only **human-fielded**
teams — a bot seat's team is never "usage".

**Deliberate policy decisions — do not "fix" without asking:**

| decision | value |
|---|---|
| bucketing | **PvP = Quick + Ranked**, **Bot tracked separately**, **Private excluded entirely** |
| aggregation | **global** (character popularity / meta), not per-player |
| access | **admin-only**, via `admin_character_stats` → the "Char Usage" tab |

> [!warning] A ladder-vs-bot match is filed under BOT, not RANKED
> ```gdscript
> var usage_type = BattleManager.MatchType.BOT if (winner_is_bot or loser_is_bot) else nmatch.match_type
> ```
> The dashboard buckets Quick+Ranked as "pvp" and humans win the overwhelming majority of bot games,
> so recording those picks as PvP would inflate the meta win rate of whatever they fielded with
> results no human ever contested.

`StatsDB.EXCLUDED_USERS` drops the dominant test accounts' own fielded teams at both record and
backfill time (opponents still count). Because aggregates don't retain usernames, exclusion cannot
be a query-time filter — applying it retroactively means deleting the DB once so it re-backfills.

### Date-windowed stats

The running `character_usage` aggregate is keyed on `(character_path, match_type)` and its
`updated_at` is **overwritten on every write**, so a period can never be subtracted back out of it —
"how did this character do since the patch" was structurally unanswerable. A second table
`character_match` (one row per `(match_id, character_path)`, PK + `INSERT OR IGNORE`) makes recording
idempotent, so re-running a backfill or double-recording cannot inflate history. The aggregate is
unchanged and still serves the unfiltered view.

`_admin_character_stats(from_ts, to_ts)`: `0/0` keeps reading the aggregate; **any** window switches
to the dated table. The handler echoes back `data_from`/`data_to` (the true span) so the UI cannot
offer a range that contains nothing.

> [!info] Known limitation: backfilled history is PvP-only
> `StatsManager._should_record` returns false for any match containing a bot, so BOT and
> ladder-vs-bot games were never written to `stats/matches/*.json` and are **not recoverable**.
> Measured on the live DB: aggregate 267 picks vs windowed 174 — the 93-pick gap is exactly BOT 84 +
> ladder-vs-bot 6 + 3 stray Quick. Quick itself recovered 168/171 (98%). Going forward the live path
> writes both tables for every non-private match *including* bot games, so the two converge.

## Bot tuning from the panel

`admin_set_bot_tuning` overwrites `res://bot_tuning.json` after `_validate_bot_tuning` confirms it is
a dict carrying the right format tag, then sets `BattleManager._live_tuning_mtime = -1` to invalidate
the in-process mtime cache — otherwise a second save within the same wall-clock second would not
hot-reload. Live bots pick it up without a restart. See [[Bots and Training]] for what the knobs mean.

## Legacy account-safety holes (known, deliberately unfixed)

Found by an adversarial account-safety audit after a test harness deleted the `Cheshire` account.
**All pre-existing legacy code**, all gated on the legacy Godot RPC listener that
`actually_start_server()` still binds best-effort on `TARGET_PORT = 5696` even though the web client
is the only client ([[System Overview]]). The owner was asked and chose to **leave** them — this
section is a reference if they are ever revisited, not a to-do.

| severity | hole |
|---|---|
| CRITICAL | `update_player_avatar_data` — `@rpc("any_peer")`, ignores the sender, uses the **client-supplied** username to `load_player` then `FileAccess.open("ausers/"+username+".dat", WRITE)`: unauthenticated overwrite of any account plus `../` path traversal. **Dead code, zero callers** — cheapest fix is deletion. |
| HIGH | clan-name traversal chain: `receive_clan_creation_request` copies the wire clan name unvalidated into `save_clan` (arbitrary-path write) and into `player.clan`; `_clan_name_valid` guards only the JSON path. `_json_clan_disband` then does a **relative** `DirAccess.open("clans").remove(actor.clan + ".dat")`, so `actor.clan = "../ausers/victim"` deletes an account file. |
| MEDIUM | non-atomic saves — `save_player` does `FileAccess.open(..., WRITE)` (truncates) then `store_line`. A crash between the two **empties the account**. No temp-file+rename anywhere. |
| MEDIUM | `resave_player` **fails open** — it re-reads the `.dat` to recover `pass_hash`; if that read returns null at that instant, `pass_hash` becomes `""` and it writes a full but **passwordless** account, which the login handler's legacy-migration branch lets anyone claim. It should fail *closed*. |

> [!danger] Harness rule that came out of the incident
> The `Cheshire` account was destroyed by a **test harness**, not by deployed code: a probe called
> `mk("Cheshire")` → `save_player`, then an `rm ausers/Cheshire.dat` cleanup. **Harnesses must use
> throwaway `ZZ_`-prefixed usernames and must never write real or admin names into the live
> `ausers/` dir.** A test needing admin should stub `_is_admin` or use a `ZZ_` name in a local admin
> list. When a live harness must touch accounts at all: stage a synthetic accounts dir, fingerprint
> the real one first (sha256), restore and re-verify the hash afterwards — and delete the `ZZ_*`
> registration it leaves behind.

## One client-authoritative debit worth knowing

Bounty **square auto-complete** is client-authoritative: the AP debit rides `save_cosmetics`, whose
handler does a bare `ap = data["ap"]`. There is no server constant and no validation, so a modified
client can fill squares for free. `donate` and `complete_bounty` **are** validated server-side; the
square buy is not. Same posture as the legacy holes above — known, accepted.

Related: [[Server Authority Model]], [[Matchmaking and the Ladder]], [[Bots and Training]],
[[Season Reset and Maintenance]], [[The Nexus]], [[Social Clans and Chat]],
[[Hard Rules and Guardrails]], [[Traps That Have Bitten Us]], [[Anime Arena]].
