# Anime Arena — Client ⇄ Server Wire Contract

**Status:** extracted 2026-08-05 from the live implementation. This document is the **acceptance
criteria for the replacement backend**: a new server is correct when it serves every frame below
with the same field names, the same types, the same authority rules, and the same lifecycle.

**Sources of truth (read in both directions and reconciled):**

| Direction | Source | Location |
|---|---|---|
| Inbound (client → server) | the `match t:` dispatch inside `_on_json_message` | `components/server_connection.gd:752-1440` |
| Outbound (server → client) | every `json_gateway.send / send_queued / broadcast / broadcast_except` and every `send_to_peer(peer, "<method>", {...})` | `components/server_connection.gd` (whole file) |
| Client expectations | the `S.net.on("<type>", …)` handler table | `webclient/app/app.js:243-896` |
| Client emissions | `S.net.send("<type>", …)` + `clanAction/socialAction` + the keepalive in `net.js` | `webclient/app/app.js`, `webclient/app/net.js` |
| Transport | `JsonGateway` | `webclient/json_gateway.gd` |
| Battle payload shapes | pre-existing doc, still accurate for snapshot/event schemas | `MATCH_PROTOCOL.md` |

**How the real inbound list was derived (not by grepping quoted strings).** A naive
`grep '"[a-z_]*"'` over `server_connection.gd` returns ~228 strings, most of which are dictionary
keys, effect names, cosmetic ids and log text. The authoritative list is the set of `match` arms of
the single dispatch statement at `server_connection.gd:770`. Those arms are exactly the string
literals appearing at **two-tab indentation immediately inside `match t:`**, where `t =
str(msg.get("type",""))`. Extracting only that syntactic position yields **89 message types plus the
`_` default arm** (`{"type":"error","reason":"unhandled type: <t>"}`). Nothing else on the socket is
dispatchable — there is no second router, no `args` array form, and no nested sub-dispatch except
inside `authored_upload_*` (which re-reads `msg.type` in `_authored_upload`, but only for the three
types the outer dispatch already routed there).

**Reconciliation result.** The server dispatches **89 inbound** types and emits **71 outbound** types.
The client sends nothing the server does not handle, and handles nothing the server does not send.

> ⚠ **The frontend Creator removal landed in `app.js` while this extraction was running.**
> `webclient/app/app.js` (and its byte-identical `deploy/app.js` mirror) went from 7895 to **6147**
> lines and now contains **zero** `authored_` references. The measurements below are taken against
> that current client. The **server** still carries the entire `authored_*` surface (this stage is
> read-only on `.gd`), so all 25 Creator frames are now server-only orphans. Both baselines are
> recorded so nothing is lost:
>
> | | Before the removal (start of this run) | Now |
> |---|---|---|
> | client `S.net.on` handlers | 67 + `_close` | **57** + `_close` |
> | distinct client-sent types | 88 (67 literal + 21 wrapper) + `ping` | **75** (54 literal + 21 wrapper) + `ping` |
> | inbound 1:1 with the client | yes, all 89 | 76 of 89; the 13 unsent are all Creator |
> | outbound with a client handler | 67 of 71 | 57 of 71 |

Full per-name lists are in §8 and in the machine-readable companion `wire_contract.json`.

---

## 1. Transport and framing

* **One WebSocket**, raw (not Godot high-level multiplayer). Server listens on TCP **5695**
  (`JSON_GATEWAY_PORT`), production behind nginx at `wss://server.animaslashanimearenaserver.org`;
  local dev is `ws://127.0.0.1:5695`.
* The legacy `WebSocketMultiplayerPeer` server on port **5696** is **removed**. Any residual
  `rpc_id(...)` calls in `server_connection.gd` (`attempt_login`, `send_hero_ban`, `update_cosmetics`,
  `receive_kick`, …) are **dead client-side helpers** from the retired Godot desktop client. They are
  never reached on a server build. **Do not port them.**
* Every frame is one **UTF-8 text** WebSocket message containing a single **JSON object**. Binary
  frames are ignored. A non-object frame is dropped with a server-side warning and no reply.
* Envelope both directions: `{"type": "<name>", ...fields}`. There is no envelope, no request id,
  no correlation id, and no sequence number. Responses are matched by type alone.
* Outbound has two paths:
  * `send()` — direct `send_text`. **Silently drops** the frame if the peer's 64 KB outbound buffer
    is full (only reproducible over a real network).
  * `send_queued()` — per-peer FIFO drained by `poll()` with a 60000-byte headroom check; nothing is
    dropped while the socket lives. **Required** for bursts of large frames. Currently used by:
    `replay_data`, `authored_asset_data`, `admin_training_status`, `authored_list`, `authored_spec`,
    and the `_authored_save` / `_authored_validate` replies.
  * *New-backend requirement:* any frame that can exceed a few KB, or that is emitted in a burst,
    must go through a backpressured queue.
* `broadcast()` / `broadcast_except(exclude, …)` fan out to every connected socket (used by
  `announcement`, `nexus_state`, and the maintenance frames).

---

## 2. Session and connection lifecycle

### 2.1 Peer-id namespaces

Three disjoint integer ranges share one id space. The new backend must preserve the separation (the
values themselves are internal, but the *bot seat is peer-less* property is load-bearing).

| Range | Meaning |
|---|---|
| `>= JSON_PEER_BASE` (1 000 000 000) | a web client. `logical_peer = JSON_PEER_BASE + gateway_local_id`; `_json_local()` maps back for sends. |
| `<= BOT_PEER_BASE` (−1000), decreasing | a synthetic server bot seat. Has **no session and no `peer_map` entry**, so every peer-guarded broadcast and save skips it automatically. |
| 1…N (positive, small) | legacy Godot multiplayer peers. **No longer produced.** `send_to_peer` `push_error`s on one. |

### 2.2 Session objects

```
ServerSession {
  username: String
  peer_id: int                       # logical peer
  player_data: Player                # the live, authoritative account object
  status: ONLINE | DISCONNECTED | IN_GAME     # only ONLINE and DISCONNECTED are used
  current_match: Match | null        # a PLAYER's match, or a SPECTATOR's watched match
  disconnect_timer: Timer | null
  rate_buckets: { key -> [monotonic ms stamps] }
}
sessions: { username -> ServerSession }      # one session per account, server-wide
peer_map: { peer_id -> username }            # reverse index
```

`get_player(peer_id)` = `sessions[peer_map[peer_id]].player_data` or `null`. **Every authenticated
handler starts with this lookup** — that is the entire auth mechanism. There is no token, no cookie,
no session id on the wire; identity is "which socket is this frame on".

### 2.3 Login / register / reconnect

`login` and `register` are refused outright while the maintenance lock is on (reply
`maintenance_locked`). Otherwise:

**Register** (`_process_register`): trims the username; rejects empty user or password, an existing
`ausers/<name>.dat`, and any case-variant collision with an `ADMIN_USERNAMES` entry. On success
creates the account with **25 000 AP** welcome bonus and writes `ausers/<name>.dat`. Replies
`receive_register_response {message}` — the client decides success by regex `/success/i` on the
message string (a fragile contract the new server must keep, or fix on both sides simultaneously).

**Login** (`_process_login`) — passwords are compared as **plaintext** against `pass_hash` (the field
name is a lie; there is no hashing). An account whose `.dat` predates the field has the supplied
password written in as its `pass_hash` on first login. Three cases:

| Case | Condition | `id` | Effect |
|---|---|---|---|
| A — resume | session exists and `status == DISCONNECTED` | **2** | cancels the wipe timer, re-points `session.peer_id`, sets ONLINE, re-adds `peer_map`, pushes presence "online", sends `global_chat_state` + `creator_state`, re-links the live match (`check_in_player`), notifies the opponent `receive_opponent_reconnect_notification`, and sends `receive_session_reconnect` after the login response |
| B — reject | session exists and is not DISCONNECTED | **0** | message `"Account already logged in."` |
| C — fresh | no session | **1** | reloads the account **from disk** (never the possibly-stale cache), creates the session, pushes presence, sends `global_chat_state` + `creator_state` |
| — fail | wrong password / no such account | **0** | `"Incorrect password."` / `"No player with that username exists."` |

After the response, `login` **always** sends the current maintenance state
(`maintenance_cleared` when there is none, `maintenance_notice` when a warning is live) so a client
carrying a stale banner from before a restart clears it.

### 2.4 Keepalive

`net.js` sends `{"type":"ping"}` every **25 s** while the socket is OPEN. The server answers
`{"type":"pong","echo":<msg.payload or null>}`. Purpose: nginx/LB idle timeouts (~60 s) were closing
idle lobby sockets, producing a reconnect churn loop. The client does **not** consume `pong`.

There is also a **server-initiated** ping cycle (`server_ping_cycle`, every 15 s) that force-disconnects
sessions which miss a pong — but it **explicitly skips JSON peers** (`not _is_json_peer(...)`), because
the gateway's own `poll()` already detects dead sockets. With the Godot transport gone this loop is
effectively dead code. **Do not port it**; port the client keepalive instead.

### 2.5 Disconnect, hold, and wipe

`_on_json_disconnected(gateway_pid)` → `handle_disconnect(logical_peer)`:

1. `_release_queues(peer)` — always. Clears the quick queue, **every** ranked bucket (not just the
   player's current one — a rating change while queued used to strand the entry), the private invite,
   the ranked wait stamp, and bumps the fallback generation counter.
2. Remove from every match's spectator list.
3. **Spectator detach first**: if `session.current_match` is set but the user is *not* one of that
   match's players, drop the pointer and take the lobby path. Without this, a disconnecting spectator
   would be auto-surrendered 120 s later out of a game they were only watching.
4. If in a real match → `status = DISCONNECTED`, push presence "disconnected", `check_out_player`
   (which pauses the turn clock — see §2.6), notify the opponent
   `receive_opponent_disconnect_notification`, and arm a **`RECONNECT_TIMEOUT` = 120 s** one-shot
   timer that calls `wipe_session`.
5. Else → `wipe_session` immediately.
6. `peer_map.erase(peer)` unconditionally.

`wipe_session(username)`: if the session still holds a match **and the user is a participant**,
`finalize_surrender` (they lose). If they are a spectator, just detach. Then push presence "offline"
and erase the session.

`match_ended` also wipes any DISCONNECTED session bound to *that* match — with an **identity check**
(`sessions[u].current_match == ended_match`) so a late teardown of a stale match cannot steal the
pointer to a live one.

### 2.6 Turn timer, AFK penalty, forfeit

Per-match, in `components/match.gd`:

* `default_match_timer = 120 s`.
* `AFK_PENALTY_STEP = 30 s`, `AFK_MIN_TIMER = 30 s`, `AFK_FORFEIT_MISSES = 3`.
* `_timer_seconds_for(peer) = max(30, 120 − 30 × consecutive_misses[peer])`.
* A **manual** turn (`apply_input`) erases that peer's miss count. A bot acting does **not**.
* Three consecutive timeouts → `_forfeit_afk_player` → the shadow's `end_match` with the AFK player
  as the loser (a real recorded loss, full bookkeeping).
* The remaining duration rides the wire as `snapshot.turn_timer` on every `apply_turn_result`,
  and as the **remaining** time (not the full duration) in reconnect and spectate-init snapshots.
* The clock is **paused exactly while the player who owes an action is disconnected**
  (`_refresh_timer_pause`, derived from live state on every rotation/check-in/check-out). The draft
  clock never pauses.
* The miss streak is carried across a reconnect (re-keyed from the old peer id to the new one), so
  reconnecting cannot shed it.

### 2.7 Maintenance: warn → eject → restart

Admin-driven, three steps, entirely **in memory** (`maintenance: Dictionary`) — the restart is the
reset.

| Step | Inbound | Server action | Broadcast |
|---|---|---|---|
| warn | `admin_maintenance {action:"warn", message, seconds}` | `maintenance = {message, locked:false, seconds}`; `seconds` clamped 0…7200; message sanitized to 200 chars | `maintenance_notice {message, seconds, boot_id}` to **everyone** |
| eject | `admin_maintenance {action:"eject", message}` | `locked = true`, then **`_maintenance_stand_down()` runs BEFORE the broadcast**: cancels every live match as a no-contest and empties every queue | `maintenance_eject {message, boot_id}` via `broadcast_except(_admin_peer_ids())` |
| cancel | `admin_maintenance {action:"cancel"}` | `maintenance = {}` | `maintenance_cleared {boot_id}` to everyone |

* The stand-down is not optional: without it an ejected player simply stops taking turns and the AFK
  timer forfeits them a real ranked loss, and anyone inside their 120 s grace is surrendered by
  `wipe_session` when the login lock refuses their re-login.
* **Admins are excluded from the eject** — an admin on the login screen loses the admin panel and with
  it the Cancel button. The exclusion list is built from **gateway-local** ids (`_json_local`), not
  logical ids.
* Sockets are deliberately **not** force-closed. The operator stopping the process is the `_close`
  the ejected clients are waiting for.
* `boot_id = "<unix_seconds>_<randi>"`, regenerated on every process start. It is the **only**
  reliable "this is a different server" signal. Ejected clients poll `server_status` every 3 s
  (pre-auth) and reload the page when the `boot_id` changes. The client also calls `noteBootId()` on
  *any* frame carrying one (`maintenance_notice`, `maintenance_cleared`, `server_status`) and reloads
  on a change, which catches clients that were offline during the eject.

### 2.8 Session ↔ match binding (anti-spoof cornerstone)

A match id **never appears on the wire from the client**. `session.current_match` is the only thing
that decides which match a turn, a surrender, a match-chat message, or a match-chat history request
applies to. `submit_turn_input` does carry `match_id`, but the server's parameter is named `_match_id`
and is **unused** — the client always sends `0`.

---

## 3. Anti-spoof and server-authority invariants

These are security properties, not implementation details. **The replacement backend must preserve
every one of them.** They are grouped by the invariant, with the enforcement site.

### 3.1 Identity and routing

1. **Identity is the socket.** `get_player(peer)` / `get_session(peer)`. No client frame carries a
   username-as-identity for the actor. Where a `username` field exists it is always a *target*, never
   the actor.
2. **The client never supplies a match id.** §2.8. Applies to `submit_turn_input`, `surrender`,
   `submit_ban`/`submit_pick`/`lock_bans`/`draft_hover`, `chat_send{channel:"match"}`,
   `chat_history{channel:"match"}`, `spectate_leave`.
3. **Peer-id reuse guard.** Every match broadcast re-checks `peer_map[peer] == match.get_expected_username(peer)`
   before sending. A recycled peer id can never receive another player's match stream.
4. **Spectators are not players.** A spectator's session also carries `current_match`. Four separate
   sites re-check participation against `match.get_player_usernames()`: `process_surrender`,
   `_process_turn_input`, `chat_send{match}`, `chat_history{match}` — plus the disconnect and
   wipe paths. Losing any one of them lets a watcher end, play, or read a game they are not in.

### 3.2 Admin

5. **`ADMIN_USERNAMES = ["Cheshire", "IsaacTheEmperor"]`, exact-case.** `_is_admin` is deliberately
   case-**sensitive** because the production filesystem (`ausers/<name>.dat`) is case-sensitive: a
   case-insensitive check would let anyone register `cheshire` and inherit admin.
6. **Registration rejects case-variants of admin names** (`_collides_with_admin_name`), defense in depth.
7. **Every `admin_*` handler re-checks `_is_admin` server-side.** The client's UI gating is
   convenience only. Same for the two leader-gated clan ops (`clan_reset_record`, `clan_set_banner`)
   and every other leader-only clan action.
8. **`is_admin` is a server-computed field** in the login response, never client-asserted.
9. **Season reset defaults to a dry run** and requires `dry_run:false` **plus** the exact confirm
   phrase `"RESET SEASON"`, and takes an automatic full backup of `ausers/` first (a failed backup
   aborts the reset).

### 3.3 Path traversal / file access

10. **`_admin_get_target(uname)`** rejects `""`, `/`, `\`, `..` before the name can reach
    `ausers/<name>.dat`. Used by every target-resolving handler (admin ops, profiles, friends,
    ignore, DMs).
11. **`replay_fetch.match_id` is whitelisted** to `[0-9_]` only, after rejecting `/ \ ..`.
12. **`admin_fetch_training_replay.name`** must end `.replay` and contain no `/ \ ..`.
13. **Authored asset paths are derived from `(id, slot)` server-side** — no client string reaches the
    filesystem; `slot` must be a member of `AuthoredAssets.SLOTS`.

### 3.4 Economy and progression

14. **AP donations are debited server-side.** `donate` validates the bucket exists, the poll is open,
    and `player.ap >= amount`, then debits, persists, and echoes `receive_player_update` so the
    browser's AP is re-synced from the authority.
15. **Bounty rewards are granted server-side.** `complete_bounty` re-derives the bounty from
    `(username, path, rerolls, type)` and re-validates the bingo before granting AP / mastery XP /
    the unlock token.
16. **Mastery XP is not client-writable on the equip path.** `save_cosmetics` omits `mastery_xp`, and
    `absorb_cosmetic_update` only applies it `if 'mastery_xp' in data`.
17. **`campaign_state` is server-authoritative.** It round-trips to disk and out to the client but is
    **never** absorbed from `save_cosmetics`; it is mutated only by the `campaign_*` intent handlers.
18. **Campaign battles cannot be forged.** `campaign_start_battle` ignores the client's teams
    entirely: the encounter must be a battle step of the player's *current active beat*, and both the
    player party and the enemy team are read from `campaign_state.party` / the encounter definition.
19. **Campaign beat completion requires banked wins.** `_campaign_complete` demands a persisted
    `pending_wins` record `{activation, encounter}` for **every** battle step of the beat, scoped to
    the activation so a win banked for one beat cannot satisfy another that reuses the encounter id.
20. **Ranked rating / W-L / clan W-L are computed entirely server-side**, snapshotted *before* the
    mutation, and shipped as a display-only `ranked_result` frame. The client derives nothing.
21. **`match_history`, `friends`, `friend_requests_in/out`, `ignored`, `allow_spectators`,
    `ranked_allow_bots`, `muted`** are server-written only — present in `save()`/`load_player` but
    **deliberately absent from `absorb_cosmetic_update`**, so a modified client cannot forge a friend
    list, un-mute itself, or reset its own spectator/bot settings.

### 3.5 Matchmaking and teams

22. **The queue display package is derived server-side.** `_json_enqueue` takes only
    `characters[]` (+ `target_username` for private) and builds `p.display_package()` itself — the
    browser never supplies its own rank, rating, or cosmetics for the opponent card.
23. **Short team payloads are rejected** (`< 3` ⇒ `receive_queue_rejected`) on every entry point:
    quick, ranked, private, and immediate-bot.
24. **Ranked enqueue is idempotent** — `_release_queues` runs first, because a duplicate entry would
    let one sweep pair the same peer twice and wipe a live board.
25. **`_already_in_match` / `_in_live_match` gate every seating path**, and `Match.from_players`
    refuses to rebuild a player who still holds a live match.
26. **Self-invite and empty-target private invites are refused** with `receive_queue_rejected` (not
    `error`), because only the `receive_queue_rejected` handler clears the client's optimistic
    `queued` flag.
27. **Authored-character team gate** (`_authored_team_error`) runs on the single funnel every queued
    team passes through, plus the immediate-bot path.

### 3.6 Privacy / oracle-freedom

28. **One generic spectate denial** (`SPECTATE_DENY`) for everything about the *target* — offline, no
    such account, no match, wrong match type, not started, privacy setting, ignore, spectator cap.
    Only the actor's **own** state (already in a match / still queued) gets a specific message.
29. **Replay denial is opaque**: missing file, unreadable, unparseable, and non-participant all return
    the identical `replay_result {ok:false, note:"Replay not available"}` — no existence oracle.
30. **Friend-request delivery is oracle-free**: the actor sees an identical success and an identical
    persisted `requests_out` entry whether or not the target actually received it (blocked by ignore,
    or inbox full → silent stop, target untouched).
31. **DM to someone who ignores you** is recorded and echoed to the sender identically, then silently
    not delivered.
32. **Chat ignore is unified**: fan-out skips recipients who ignore the sender; history hides messages
    whose `from` is in the *viewer's* ignore list.
33. **Spectator streams are hidden-info-stripped**: `_spectator_safe_events` drops `invisible`-tagged
    events, `_spectator_safe_snapshot` removes every effect whose `visibility != "all"` and blanks
    `execution_preview`. Players and the persisted replay keep the full payloads.
34. **Replays are participants-only** — checked against `p1_username`/`p2_username` inside the replay
    file itself.
35. **Public profiles are a whitelist** (`_build_profile_body`), never the raw save (which holds
    `pass_hash`).
36. **`authored_asset_fetch` is three-armed**: approved **OR** the requester is the author **OR** the
    character is fielded in the requester's own live match. A blocked id answers `{missing:true}` —
    identical to a truly absent id.

### 3.7 Turn validation

37. `Match.validate_input` re-checks, against the live shadow: sender is `acting_player`; the input has
    `actions` + `execution_order` + `energy_allocation`; every `char_idx` is inside the sender's own
    canonical 3-slot range; the character is alive and not banished; the ability index is in range,
    off cooldown, and not stunned; every target index is a real character; and the **total cost is
    affordable** (RANDOM-substitution aware, and pre-applying a bundled `exchange` for web clients
    via `exchange_unapplied=true`).
38. A rejected turn answers `{"type":"error","reason":"Turn rejected — …"}` so the client re-enables
    its UI immediately instead of waiting on its watchdog.

### 3.8 Known holes the new backend should CLOSE (documented, not endorsed)

* **The shop is fully client-authoritative.** There is no `buy` message. `buyShopItem()` mutates
  `S.player.ap -= price` and pushes the unlock token locally, then persists via `save_cosmetics` —
  and `absorb_cosmetic_update` accepts **`ap`, `unlocks`, `title`, `clan`, `characters`,
  `bounty_rerolls`, `active_bounties`** verbatim from the client. A modified client can grant itself
  arbitrary AP and any unlock. **The new backend needs a server-side purchase message.**
* **Bounty square progress is client-written** (`S.player.active_bounties[key][i]` is edited
  client-side and persisted through `save_cosmetics`); only the final `complete_bounty` claim is
  re-validated — and it re-validates against the *client-supplied* progress array.
* **Passwords are plaintext** in `ausers/*.dat` and compared in plaintext. The `"keep me logged in"
  feature stores the raw password in `localStorage`.
* **`pass_hash` is echoed to the owning client.** `load_player(username, true)` re-stringifies the
  whole `.dat`, so `receive_login_response.player` and `receive_player_update.json_string` both
  include the account's plaintext password. It only reaches its own owner, but the new server should
  strip it.
* **`nexus_state` and `ladder` have no login check** — both answer an unauthenticated socket
  (`ladder` tolerates a null player and just omits the "me" row).

---

## 4. Message catalogue — INBOUND (client → server), 89 types

**Legend.**
`Auth`: `none` = works logged out · `session` = requires a logged-in session · `admin` =
`_is_admin` re-checked · `silent` = handler returns with **no reply at all** when unauthenticated.
`Scope`: **NB** = non-battle (first backend milestones) · **B** = battle (deferred, built with the new
Creator) · **NB→B** = non-battle bookkeeping that hands off into a battle.
`RL` = rate limit (`n/window`), blank = none.

### 4.1 AUTH — NB

| Type | Fields | Effect | Replies | Auth | RL |
|---|---|---|---|---|---|
| `ping` | `payload?: any` | keepalive | `pong {echo}` | none | |
| `server_status` | — | **pre-auth on purpose**: what an ejected client polls | `server_status {boot_id, maintenance:bool, message}` | none | |
| `login` | `username: str`, `password: str` | §2.3 | `maintenance_locked` **or** `receive_login_response` (+ `global_chat_state`, `creator_state`, `maintenance_cleared`/`maintenance_notice`, `receive_session_reconnect`) | none | |
| `register` | `username: str`, `password: str` | §2.3 | `maintenance_locked` **or** `receive_register_response {message}` | none | |
| `change_password` | `current: str`, `new: str` | verifies `current` against the on-disk `pass_hash`, rewrites it | `receive_change_password_response {ok, message}` | session | |

### 4.2 PLAYER STATE / PERSISTENCE — NB

| Type | Fields | Effect | Replies | Auth | RL |
|---|---|---|---|---|---|
| `save_cosmetics` | `update: {…}` (see §7.3) | `absorb_cosmetic_update` + `resave_player`. **No echo** — the client keeps its local state | *(none)* | session (silent) | |
| `get_player_profile` | `username: str` | public showcase; any logged-in player may view any player | `player_profile {profile}` or `error` | session | |
| `reset_own_record` | — | zeroes **only the caller's** W/L, streak, RP, rating; cannot be pointed at another account (no target field) | `record_reset {ok, profile}` + `receive_player_update` | session | |
| `social_setting` | `key: "allow_spectators"\|"ranked_allow_bots"`, `value` | writes the two server-only settings; `allow_spectators` ∈ {all,friends,off}. Tightening it **evicts current watchers** who no longer qualify | `social_result {ok, note}` (+ `spectate_result {ok:false}` to evicted watchers) | session | |

### 4.3 SOCIAL — NB

All target resolution goes through `_admin_get_target` (traversal-safe). All mutating ops resave
**both** players and push `social_state` to both.

| Type | Fields | Effect | Replies | Auth | RL |
|---|---|---|---|---|---|
| `social_state` | — | snapshot | `social_state {friends:[{username,status}], requests_in[], requests_out[], ignored[]}` | session | |
| `friend_request` | `username` | mutual-request auto-accept; else records outgoing. Caps: friends 100, pending 50 | `social_result` (+ `social_state` to both, `friend_request_notice {from}` to an online target) | session | 6/60 s |
| `friend_accept` | `username` | | `social_result` + `social_state`×2 | session | 30/60 s (`friend_mutate`) |
| `friend_decline` | `username` | existence-guarded before any write (disk-write amplifier defense) | `social_result` + `social_state`×2 | session | 30/60 s |
| `friend_cancel` | `username` | | `social_result` + `social_state`×2 | session | 30/60 s |
| `friend_remove` | `username` | | `social_result` + `social_state`×2 | session | 30/60 s |
| `ignore_add` | `username` | appends to `ignored` (cap 100) and **severs** friendship + pending requests in both directions | `social_result` + `social_state`×2 | session | 20/60 s (`ignore_mutate`) |
| `ignore_remove` | `username` | erases both the resolved canonical name and the raw typed value | `social_result` + `social_state` | session | 20/60 s |
| `chat_send` | `channel: "global"\|"match"\|"dm"`, `text`, `to?` (dm) | RAM ring buffers only. Text sanitized to 300 chars. Muted senders dropped. Global has an admin kill switch. Match channel derives the match from the session and refuses spectators | `chat_message` fan-out; `chat_result {ok:false,note}` on refusal | session | 5/10 s |
| `chat_history` | `channel`, `to?` | ring-buffer read, ignore-filtered | `chat_history {channel, to?, messages:[{from,text,ts}]}` | session | |

**Chat caps:** global 100, dm 50 per pair, match 50; ≤2000 DM buffers (LRU-evicted); 300 chars/message.
Match buffers are freed on `match_ended`. **No durable chat history.**

### 4.4 CLANS — NB

Two-tier (Leader / Member; an Officer rank exists in the data model but no message promotes to it).
Every leader-only op re-checks leadership server-side. All ops push `clan_state` to every affected
online member, and membership changes also push `receive_player_update`.

| Type | Fields | Effect | Replies | Auth |
|---|---|---|---|---|
| `clan_state` | — | snapshot: your clan detail, or (Clanless) your pending invitations + applications. **Self-heals** a dangling membership to "Clanless" | `clan_state {clan\|null, invitations[], applications[]}` | session |
| `create_clan` | `name`, `banner_url?` | name 3-24 chars `[A-Za-z0-9 \-_']`; uniqueness checked; banner sanitized to blank if not `http(s)://` (≤512 chars) | `clan_result` + `receive_player_update` + `clan_state` | session |
| `clan_search` | `query` | substring, case-insensitive, ≤40 results, sorted by member count | `clan_search_result {clans:[…]}` | session (silent) |
| `clan_apply` | `clan_name` | | `clan_result` (+ leader's `clan_state`) | session |
| `clan_cancel_application` | `clan_name` | | `clan_result` | session |
| `clan_invite` | `username` | **leader only** | `clan_result` (+ `clan_invite_notice {clan_name}` to an online target) | session |
| `clan_cancel_invite` | `username` | **leader only** | `clan_result` | session |
| `clan_accept_invite` | `clan_name` | purges the joiner's offers to other clans | `clan_result` + `receive_player_update` + `clan_state` | session |
| `clan_decline_invite` | `clan_name` | | `clan_result` | session |
| `clan_approve_application` | `username` | **leader only** | `clan_result` + target's `receive_player_update`/`clan_state` | session |
| `clan_deny_application` | `username` | **leader only** | `clan_result` | session |
| `clan_kick` | `username` | **leader only**; cannot kick the leader | `clan_result` + target updates | session |
| `clan_leave` | — | leader must Disband instead (leaving would orphan the clan) | `clan_result` + `receive_player_update` | session |
| `clan_disband` | — | **leader only**; sets every member Clanless and deletes `clans/<name>.dat` | `clan_result` + updates to all ex-members | session |
| `clan_reset_record` | — | **leader only**; zeroes wins/losses (and thus the win-derived level) | `clan_result` + `clan_state` to all members | session |
| `clan_set_banner` | `banner_url` | **leader only**; an invalid non-empty URL is **rejected and the current picture kept**; only `""` clears it | `clan_result` + `clan_state` + `receive_player_update` to all members | session |

### 4.5 MATCHMAKING / QUEUE — NB→B

| Type | Fields | Effect | Replies | Auth |
|---|---|---|---|---|
| `queue_quick` | `characters: [str]` | `_json_enqueue("quick")`. Pairs with a waiting human immediately, else arms a bot fallback after the player's own `bot_queue_delay` (clamped ≥15 s) | `receive_queue_rejected` / `error` / eventually `receive_quick_match` | session (silent) |
| `queue_ranked` | `characters: [str]` | `_json_enqueue("ranked")`. Idempotent; files into `ranked_queue[rank][tier]`, stamps the wait, arms the **fixed 20 s** bot fallback unconditionally, and runs one gate sweep immediately | `receive_queue_rejected` / `error` / eventually `receive_ranked_match` | session (silent) |
| `queue_private` | `characters: [str]`, `target_username: str` | `_json_enqueue("private")`. Pairs only on **mutual** agreement — the invite key is `(inviter → target)` and the lookup asks for the exact reverse | `receive_queue_rejected {reason?}` / eventually `receive_private_match` | session (silent) |
| `queue_bot` | `characters: [str]` | immediate practice bot match, bypassing the queue and its timer | `error` / `receive_queue_rejected` / `receive_quick_match {practice:true, vs_bot:true}` | session |
| `cancel_queue` | — | `_release_queues` (both queues + private invite + wait stamp + fallback generation bump) | *(none)* | session (silent) |

`characters[]` entries may carry suffixes the server parses: a **Toga disguise** path appended as a
4th element, and a Jin-woo summon form as a `"form:<color>"` token. `_authored_team_error` splits on
`":"` before testing authored ids.

**Ranked pairing is rating-gated** (`GATE_BANDS`, swept at 1 Hz): |Δrating| < 100 → 0 s, < 200 →
0.25×, < 400 → 0.75×, < 800 → 1.5×, else 3.0× of `RANKED_BOT_DELAY` (20 s). Bands ≥ 400 deliberately
**exceed** the bot delay so far-apart players meet a bot before each other. Gating is on **rating
points**, never badge distance (`tier_for_rating` saturates at Grandmaster 4).

**AP payout table** (`_calculate_ap_gain`, mirrored client-side in `matchApGain()` — change both):

| Queue | Win | Loss |
|---|---|---|
| Bot Match (explicit, `practice`) | 50 | 0 |
| Quick (incl. its bot fallback) | 100 | 50 |
| Ranked vs human | 500 | 50 |
| Ranked vs bot | 250 | 50 |
| Private | 0 | 0 |

**W/L record + rating move on RANKED ONLY.** Quick, its bot fallback, practice bot games and Private
leave the record untouched. Clan W/L moves only on ranked human-vs-human between different clans.
Ranked-vs-bot still records W/L but the rating movement is scaled (win capped at +25, loss ×0.5).

### 4.6 MATCH LIFECYCLE — B

| Type | Fields | Effect | Replies | Auth |
|---|---|---|---|---|
| `submit_turn_input` | `match_id` (**ignored**), `input: {…}` | validate against the shadow → apply → broadcast → drive the bot seat if it now holds the turn | `apply_turn_result` to both sides (+ stripped copy to spectators), or `error {reason}` on rejection | session + participant |
| `surrender` | — | `process_surrender` → `finalize_surrender`; drives the shadow's natural `end_match` with the surrendering side as loser | `apply_turn_result` (MATCH_ENDED) to both + `receive_surrender` to the opponent | session + **participant** (spectators refused) |
| `submit_ban` | `character`, `confirm?: bool` | **DEAD PATH** — see §8 | `error` | session + match |
| `submit_pick` | `character` | **DEAD PATH** | `error` | session + match |
| `lock_bans` | — | **DEAD PATH** | `error` | session + match |
| `draft_hover` | `character` | **DEAD PATH** | *(none)* | session + match |
| `spectate` | `username: str` | watch a target's live match | `spectate_init {info}` + `spectate_result {ok:true,note}`, or `spectate_result {ok:false,note}` | session | 5/60 s |
| `spectate_leave` | — | idempotent detach | `spectate_result {ok:true, note}` | session |
| `replay_fetch` | `match_id: str` | streams `replays/<id>.replay` as chunked frames | N × `replay_data`, or `replay_result {ok:false}` | session + participant | 10/60 s |

**`submit_turn_input.input` (the canonical-frame turn package):**

```jsonc
{
  "match_id": 0,                 // ignored server-side
  "turn_number": 7,              // informational
  "actions": [                   // may be empty (pass)
    { "char_idx": 0,             // CANONICAL 0-5: 0,1,2 = p1 slots, 3,4,5 = p2 slots
      "ability_idx": 2,          // index into the ACTIVE (post-swap) ability bar
      "target_idxs": [4, 5] }    // canonical indices; target_idxs[0] IS the main target
  ],
  "execution_order": [0, 6],     // player-chosen resolution order; 0-5 = a skill by char,
                                 // >= 6 = a ticking-effect counter id (legacy_id + 3)
  "energy_allocation": [[0,2],[3,1]],  // [[color, count], …]; the FULL per-color drain,
                                       // specific costs + assigned RANDOM pips
  "exchange": { "offer": {"1": 2}, "request": 3 } | null,
  "timeout": false
}
```

Energy colors: `0` Green, `1` Blue, `2` White, `3` Red, `4` RANDOM (never stored in a pool).
**Target order is load-bearing:** the first index in `target_idxs` becomes the targeter's
`main_target`; leading an AoE list with the wrong character resolves primary/splash on the wrong one.

**Spectate gate order** (`_json_spectate`) — own-state errors may be specific, everything about the
target is one generic denial: not logged in → rate limit → already in a match → in any queue (quick,
private, **and every ranked bucket**) → then, generically: empty/self target, target not in
`sessions`, target not ONLINE, no/cancelling match, match type not in {QUICK, RANKED, PRIVATE, BOT}
(Campaign is unwatchable), `manager == null` (draft/not started), `allow_spectators == "off"`,
`"friends"` and not a friend, actor is on the target's ignore list, ≥20 spectators, or
`get_spectator_init()` returns `""`.

### 4.7 LADDER / RANK — NB

| Type | Fields | Effect | Replies | Auth |
|---|---|---|---|---|
| `ladder` | — | top-50 by rating / wins / streak, plus clan standings, plus a "me" row when the requester is below the cut. Non-positive values are excluded from a "top" board | `ladder {ladder:{by_rating,by_wins,by_streak,clan_data}}` | **none enforced** (tolerates a null player) |

Ranks derive purely from rating: 400 points per rank, 4 divisions of 100 (`Rank.tier_for_rating`),
Iron…Grandmaster. `rank`/`tier` are shipped rather than re-derived client-side so the badge on the
ladder can never disagree with the one on the profile.

### 4.8 SHOP / COSMETICS — NB

**There is no shop message.** The entire shop is client-side against `shop_catalog.json`, persisted
through `save_cosmetics` (§4.2). See §3.8 — this is the largest authority hole in the protocol and
the replacement backend should add a real `buy` message.

### 4.9 BOUNTY / MISSIONS — NB

| Type | Fields | Effect | Replies | Auth |
|---|---|---|---|---|
| `bounty_missions` | `path: str`, `btype: "unlock"\|"mastery"` | read-only: generates the 25 missions server-side (avoids porting Godot's `hash()` + PCG32). Rerolls are read from the player so missions match server-computed progress. Key = `path` (+ `Bounty.MASTERY_SUFFIX` for mastery) | `bounty_missions {path, btype, key, rerolls, missions}` | session (silent) |
| `complete_bounty` | `bounty_path: str` (the **key**) | re-derives + re-validates the bingo; grants `+5000 AP` and `+1000` mastery XP (mastery bounty) **or** appends `<path>_unlock`; erases the bounty and its reroll counter | `receive_player_update`, or `error {reason:"bounty not complete"}` | session (silent) |

### 4.10 CAMPAIGN — NB (except `campaign_start_battle`, which is NB→B)

Pure intent/echo: the client sends an intent, the server validates against the authoritative
`campaign_state` + the shared rule tables, mutates, grants rewards, persists, and echoes. Every
handler answers with either `campaign_state` (accept) or `campaign_error` (reject, **which also ships
the authoritative state so the client reverts its optimism**).

| Type | Fields | Effect |
|---|---|---|
| `campaign_enter` | — | initializes `chapterX` if absent; **always clears `active`** and lands on the map at the last node (never auto-plays a beat) → `campaign_state {note:"enter", arrive:false}` |
| `campaign_travel` | `to: str` | target must be an edge of the current node **and** `Campaign.node_open`; marks visited, arms the beat → `{note:"travel", arrive:true}` |
| `campaign_arrive` | `node: str` | re-select the current node to (re)start its beat → `{note:"arrive", arrive:<beat exists>}` |
| `campaign_activation_complete` | `node: str`, `activation: str` | must match the beat the player is currently **inside**; every battle step must have a matching banked win; consumes the wins, marks completed (if `once`), applies `on_complete` effects, clears `active` |
| `campaign_choice` | `scene: str`, `line: int`, `choice: int` | scene must be reachable within the active beat; indices bounds-checked; applies the choice's effects |
| `campaign_abandon` | `node: str`, `activation: str` | after a lost battle: clears `active` and **discards this beat's banked wins** so it re-fights from the top |
| `campaign_set_party` | `party: [3 str]` | 3 distinct, **must include `"vessel"`**, each from the chapter's `roster_grants` + Vessel + the player's PvP unlocks |
| `campaign_set_vessel_skills` | `skills: [1-4 str]` | distinct, from `vessel1…vessel6` + `campaign_unlocked_abilities` |
| `campaign_start_battle` | `encounter: str` (+ ignored `player_team`/`enemy_team`) | see invariant 18 | → `receive_campaign_match` or `error` |

`on_complete` / choice effects apply: `set_stage`, `set_flags[]`, and `unlocks[]` where `"char:<x>"`
grants the shared PvP token `<x>_unlock` and `"ability:<k>"` appends to `campaign_unlocked_abilities`.

### 4.11 NEXUS — NB

| Type | Fields | Effect | Replies | Auth |
|---|---|---|---|---|
| `nexus_state` | — | all character buckets + current leader max + poll open state. The client groups by universe itself | `nexus_state {max, sets:[[path,ap,universe]…], poll_open}` | **none enforced** |
| `donate` | `path_name: str`, `amount: int` | invariant 14 | `update_buckets {path_name, amount, current_max}` + `receive_player_update`, or `error` | session |

Poll state comes from `bucket data/poll.dat` (a single `0`/`1`); missing/unreadable ⇒ open.

### 4.12 ADMIN — NB

Every one re-checks `_is_admin` and answers `error {reason:"Not authorized"}` otherwise.

| Type | Fields | Effect | Replies |
|---|---|---|---|
| `admin_announce` | `text` (≤500, sanitized) | server-wide marquee | `broadcast announcement {text, from}` |
| `admin_list_players` | — | snapshot of every **session** + status/stats | `admin_players {players:[{username,status,ap,wins,losses,rating,unlocks}], total_accounts}` |
| `admin_modify_player` | `target`, `op`, `value?` | ops: `grant_ap` (Δ, floored at 0), `reset_record`, `add_unlock` / `remove_unlock` (normalized to `<x>_unlock`), `mute`, `unmute`. Works on online **and offline** accounts; persists and pushes a live update | `admin_modify_result {ok, target, note, player}` or `error` |
| `admin_season_reset` | `dry_run?: bool = true`, `confirm?: str` | invariant 9 | `admin_season_reset_result {ok, dry_run?, accounts, with_record?/reset?, failed?, backup?, note}` |
| `admin_maintenance` | `action: "warn"\|"eject"\|"cancel"`, `message?`, `seconds?` | §2.7 | `maintenance_state {phase, …}` + the broadcast |
| `admin_toggle_global_chat` | `enabled: bool` | **not persisted** (resets to `true` on restart) | `global_chat_state {enabled}` to every ONLINE session |
| `admin_toggle_creator` | `enabled: bool` | **persisted** to `server_flags.json` | `creator_state {enabled}` to every ONLINE session |
| `admin_character_stats` | `from_ts?: int`, `to_ts?: int` (0 = all time) | per-character usage/win aggregates, bucketed pvp (Quick+Ranked) vs bot; Private excluded | `admin_character_stats {stats[], from_ts, to_ts, data_from, data_to}` |
| `admin_close_nexus_round` | `count: int` | removes the top *count* buckets permanently and halves the rest | `broadcast nexus_state` + `nexus_round_closed {removed[], remaining, current_max}` |
| `admin_scale_nexus_ap` | `multiplier: float > 0` | multiplies every bucket | `broadcast nexus_state` + `nexus_scaled {multiplier, count}` |
| `admin_training_status` | — | bot-training dashboard snapshot, read fresh from disk; replays capped at 24, elo history at 40 | `admin_training_status {status, elo, live_generation, replays[]}` (**send_queued**) |
| `admin_get_bot_tuning` | — | reads `bot_tuning.json` | `admin_bot_tuning {tuning}` |
| `admin_set_bot_tuning` | `tuning: object\|json-string` | shape-validated, written to disk, mtime cache invalidated so live bots hot-reload | `admin_bot_tuning_saved` or `error` |
| `admin_fetch_training_replay` | `name: str` (`*.replay`, no traversal) | streams a training replay through the **same chunk protocol** as PvP replays, keyed `"train_<name>"` | N × `replay_data`, or `replay_result {ok:false}` |

### 4.13 CREATOR — **SCRAPPED. DO NOT PORT.** — B

> The block-based Character Creator is being removed and redesigned from the ground up, together with
> battle execution. **The roadmap should skip this entire section.** It is documented only so the
> reader can recognise these frames if they appear in a capture, and so the *shape* of the asset
> pipeline (chunked base64 over the socket) is on record.
>
> **As of this run the web client no longer sends or handles any of these frames** — the frontend
> removal landed mid-extraction (see F11). Everything below describes the *server*, which still
> implements them and will keep doing so until the Godot backend is retired.
>
> Guarded by a **kill switch**: any inbound type starting `authored_` **except** `authored_asset_fetch`
> is refused with `error {reason:"The Character Creator isn't available yet"}` unless
> `creator_enabled` (persisted in `server_flags.json`, default `false`) or the caller is an admin.
> `authored_asset_fetch` sits outside the gate so an opponent can render art for a character fielded
> against them.

| Type | Fields | Replies |
|---|---|---|
| `authored_list` | — | `authored_list {mine[], approved[], review[], palette}` |
| `authored_get` | `id` | `authored_spec {spec}` / `error` |
| `authored_save` | `spec: object\|json-string` | `authored_saved {id,status}` / `authored_invalid {id,errors[]}` / `error` |
| `authored_submit` / `authored_unsubmit` | `id` | `authored_saved {id,status}` / `error` |
| `authored_delete` | `id` | `authored_deleted {id}` / `error` |
| `authored_review` | `id`, `verdict: "approved"\|"rejected"`, `note?` | **admin only** → `authored_reviewed {id,status}` |
| `authored_validate` | `spec` | `authored_validated {errors[], abilities[]}` |
| `authored_asset_fetch` | `id`, `slot = "portrait"` | N × `authored_asset_data {id,slot,part,total,data}` or `{…,missing:true}` |
| `authored_upload_begin` | `id`, `slot`, `bytes`, `chunks`, `ability_index?`, `ability_name?` | `authored_upload_ready` / `error` |
| `authored_upload_chunk` | `part`, `data` (base64) | `authored_upload_ack {part}` / `error` |
| `authored_upload_end` | — | `authored_upload_done {id, slot, ability_index}` / `error` |

Authored characters are currently **admin-only to field** (`AuthoredRegistry.can_use` returns
`is_admin`); unapproved work is confined to bot/private matches.

---

## 5. Message catalogue — OUTBOUND (server → client), 71 types

| Type | Trigger | Payload | Category | Scope |
|---|---|---|---|---|
| `pong` | `ping` | `{echo}` | AUTH | NB |
| `server_status` | `server_status` | `{boot_id, maintenance:bool, message}` | AUTH | NB |
| `receive_login_response` | `login` | `{json_string}` → JSON string of `{id:0\|1\|2, player:<json string of the .dat>, message, version:"1.6.0", is_admin}` (**double-encoded**; `player` includes `pass_hash`) | AUTH | NB |
| `receive_register_response` | `register` | `{message}` (client tests `/success/i`) | AUTH | NB |
| `receive_change_password_response` | `change_password` | `{ok, message}` | AUTH | NB |
| `receive_session_reconnect` | login case A with a live match | `{info}` → JSON string of `{enemy, player_characters[], enemy_characters[], snapshot, current_timer, match_type, practice, vs_bot, canonical_role}` | MATCH | B |
| `receive_player_update` | any server-side account mutation | `{json_string}` → the raw `.dat` JSON (includes `pass_hash`) | PLAYER | NB |
| `error` | 66 sites | `{reason}` | MISC | both |
| `maintenance_locked` | login/register during the lock | `{message, boot_id}` | ADMIN | NB |
| `maintenance_notice` | warn broadcast + every login during a warning | `{message, seconds, boot_id}` | ADMIN | NB |
| `maintenance_eject` | eject broadcast (admins excluded) | `{message, boot_id}` | ADMIN | NB |
| `maintenance_cleared` | cancel broadcast + every login with no maintenance | `{boot_id}` | ADMIN | NB |
| `maintenance_state` | ack to the acting admin | `{phase:"warn"\|"ejected"\|"off", message?, seconds?, matches_cancelled?, dequeued?}` | ADMIN | NB |
| `announcement` | `admin_announce` | `{text, from}` — broadcast | ADMIN | NB |
| `global_chat_state` | admin toggle + every login | `{enabled}` | SOCIAL | NB |
| `creator_state` | admin toggle + every login | `{enabled}` | CREATOR | — |
| `receive_queue_rejected` | 7 sites | `{reason?}` — **clears the client's optimistic `queued` flag** | QUEUE | NB |
| `receive_quick_match` | quick pair, quick bot fallback, practice bot | `{opponent, opponent_team[], first_turn, seed, canonical_role, practice?, vs_bot?}` | MATCH | NB→B |
| `receive_ranked_match` | ranked pair, ranked bot fallback, drafted battle | same shape | MATCH | NB→B |
| `receive_private_match` | mutual private invite | same shape | MATCH | NB→B |
| `receive_campaign_match` | `campaign_start_battle` | same shape `+ {encounter}` | CAMPAIGN | NB→B |
| `apply_turn_result` | every turn, timeout, surrender, and match end | `{events:[…], snapshot:{…, turn_timer}}` — spectators get the stripped copy | MATCH | B |
| `receive_surrender` | opponent surrendered | `{}` — **redundant; the client has no handler** | MATCH | B |
| `receive_opponent_disconnect_notification` | opponent dropped | `{}` | MATCH | B |
| `receive_opponent_reconnect_notification` | opponent returned | `{}` | MATCH | B |
| `ranked_result` | ranked match end, one per human | `{won, rating_before, rating_after, delta, rank_before, tier_before, rank_after, tier_after, promoted, demoted, rank_changed}` | LADDER | NB |
| `draft_start` | `start_ranked_draft` | `{opponent, pool[], my_role, first_picker_role, max_bans:3, phase:"BAN", phase_seconds:60, deadline_unix}` — **dead path** | MATCH | B |
| `draft_update` | draft state change | `draft_state_for(peer)` — **dead path** | MATCH | B |
| `campaign_state` | every accepted campaign intent | `{state, unlocks, note, arrive}` | CAMPAIGN | NB |
| `campaign_error` | every rejected campaign intent | `{reason, state, unlocks}` | CAMPAIGN | NB |
| `ladder` | `ladder` | `{ladder:{by_rating,by_wins,by_streak,clan_data}}` | LADDER | NB |
| `player_profile` | `get_player_profile` | `{profile:{username,wins,losses,rating,streak,rank,tier,clan,title,avatar_url,player_card,clan_banner,status,top_mastery[5],match_history[]}}` | PLAYER | NB |
| `record_reset` | `reset_own_record` | `{ok, profile}` | PLAYER | NB |
| `nexus_state` | `nexus_state` + both admin nexus ops (broadcast) | `{max, sets, poll_open}` | NEXUS | NB |
| `update_buckets` | `donate` | `{path_name, amount, current_max}` | NEXUS | NB |
| `nexus_round_closed` | admin | `{removed[], remaining, current_max}` | NEXUS/ADMIN | NB |
| `nexus_scaled` | admin | `{multiplier, count}` | NEXUS/ADMIN | NB |
| `bounty_missions` | `bounty_missions` | `{path, btype, key, rerolls, missions}` | BOUNTY | NB |
| `clan_state` | `clan_state` + every clan mutation, to every affected online member | `{clan\|null, invitations[], applications[]}` | CLAN | NB |
| `clan_result` | every clan op | `{ok, note}` | CLAN | NB |
| `clan_search_result` | `clan_search` | `{clans[]}` | CLAN | NB |
| `clan_invite_notice` | `clan_invite`, to an online target | `{clan_name}` | CLAN | NB |
| `social_state` | `social_state` + every social mutation, to both parties | `{friends[{username,status}], requests_in[], requests_out[], ignored[]}` | SOCIAL | NB |
| `social_result` | every social op + `social_setting` | `{ok, note}` | SOCIAL | NB |
| `friend_presence` | login / disconnect / wipe, to each online friend | `{username, status:"online"\|"offline"\|"disconnected"}` | SOCIAL | NB |
| `friend_request_notice` | delivered friend request | `{from}` | SOCIAL | NB |
| `chat_message` | `chat_send` fan-out | `{channel, from, text, ts, to?}` | SOCIAL | NB |
| `chat_result` | refused `chat_send`/`chat_history` | `{ok:false, note}` | SOCIAL | NB |
| `chat_history` | `chat_history` | `{channel, to?, messages:[{from,text,ts}]}` | SOCIAL | NB |
| `spectate_init` | accepted `spectate` | `{info}` → JSON string of `{p1,p2,p1_characters[],p2_characters[],snapshot,match_type,current_timer}` | MATCH | B |
| `spectate_result` | `spectate`, `spectate_leave`, eviction by `social_setting` | `{ok, note}` | MATCH | B |
| `replay_data` | `replay_fetch`, `admin_fetch_training_replay` | `{match_id, part, total, data}` — `REPLAY_CHUNK` = 24000 chars per part; **send_queued** | MATCH | B |
| `replay_result` | replay denial | `{ok:false, note}` | MATCH | B |
| `admin_players` | admin | `{players[], total_accounts}` | ADMIN | NB |
| `admin_modify_result` | admin | `{ok, target, note, player}` | ADMIN | NB |
| `admin_season_reset_result` | admin | `{ok, dry_run?, accounts, …, note}` | ADMIN | NB |
| `admin_character_stats` | admin | `{stats[], from_ts, to_ts, data_from, data_to}` | ADMIN | NB |
| `admin_training_status` | admin | `{status, elo, live_generation, replays[]}` | ADMIN | NB |
| `admin_bot_tuning` | admin | `{tuning}` | ADMIN | NB |
| `admin_bot_tuning_saved` | admin | `{}` | ADMIN | NB |
| `authored_list` / `authored_spec` / `authored_saved` / `authored_invalid` / `authored_validated` / `authored_deleted` / `authored_reviewed` / `authored_asset_data` / `authored_upload_ready` / `authored_upload_ack` / `authored_upload_done` | Creator | see §4.13 | **CREATOR — skip** | — |

---

## 6. Battle payload schemas (deferred, cross-reference)

`apply_turn_result`, `receive_session_reconnect.snapshot`, and `spectate_init.snapshot` all carry the
**wire snapshot** produced by `BattleManager.serialize_wire_snapshot()`, plus a server-added
`turn_timer` (seconds). Its full schema — sides, energy pools, per-character `abilities` (with
server-resolved `cost` / `usable` / `special_targets` / `target_type` the client uses **verbatim**),
`effects`, and the event stream — is already documented in **`MATCH_PROTOCOL.md` §2-3**, which was
verified against the current serializers while writing this document. It is deliberately not
duplicated here: the snapshot/event schema is co-owned by battle execution and will be re-designed
with the new Creator.

The one thing to carry forward now: **the canonical 0-5 character frame** (0,1,2 = p1 slots; 3,4,5 =
p2 slots; ≥6 in `execution_order` only = ticking-effect ids), and `canonical_role` (0 = p1, 1 = p2)
delivered in the match-start frame. `role` / `side` / `acting_role` appear on the wire as the strings
`"p1"` / `"p2"`.

---

## 7. Player persistence — `ausers/<username>.dat`

**Verified plain JSON**: one single-line JSON object, written by `save_player` as
`JSON.stringify(player.save())` + `store_line`. Read back with `FileAccess.get_line()` + `JSON.parse`.
No compression, no encoding, no header. The filename **is** the username (which is why every
target-resolving handler must reject `/ \ ..`).

Confirmed by inspecting a throwaway `ZZ_`-prefixed account. `load_player()` blanks `missions` to `{}`
on every read, so that key is vestigial.

### 7.1 Field set

Written by `scripts/player_component.gd::save()` plus `pass_hash` (injected by `save_player`).
"Client-writable" = present in `absorb_cosmetic_update`, i.e. a `save_cosmetics` frame overwrites it.

| Field | Type | Meaning | Client-writable? |
|---|---|---|---|
| `username` | string | account name; equals the filename stem | no |
| `pass_hash` | string | **plaintext password**, despite the name. Written only when non-empty, so `resave_player` preserves it | no |
| `wins` / `losses` | int | ranked record | **no** (server-only) |
| `rank` / `tier` | int | **not loaded back** — the badge is re-derived from `rating` on every read. Kept in the file as a human-readable record | no |
| `rating` | int | ladder rating; the single source of rank/tier | no |
| `rp` | int | `Rank._rp` | no |
| `streak` | int | overall win streak | no |
| `ranked_streak` | int | `Rank._ranked_streak` | no |
| `ap` | number | Arena Points currency (floats appear in real saves) | **yes** ⚠ (see §3.8) |
| `unlocks` | [string] | `"<path>_unlock"` gate tokens; `"all_unlock"` unlocks everything | **yes** ⚠ |
| `title` | string | composed player title | yes |
| `clan` | string | clan name or `"Clanless"` | yes |
| `muted` | bool | chat mute (moderation) | **no** — deliberately absent from absorb |
| `characters` | [string] ≤3 | last equipped team (path_names) | yes |
| `character_frames` | [string] ×3 | portrait frame cosmetic per slot | yes |
| `action_frames` | [string] ×3 | game/elite panel cosmetic per slot | yes |
| `hats` | [string] ×3 | hat cosmetic per slot (`"None"`) | yes |
| `mastery_profiles` | [string] | mastery portrait cosmetics | yes |
| `mastery_skins` | [string] | mastery skins | yes |
| `charselect_background` | string | | yes |
| `ingame_background` | string | | yes |
| `player_card` | string | | yes |
| `avatar_url` | string | remote avatar image URL | yes |
| `cosmetics_on` | bool | master cosmetics toggle | yes |
| `mark_significant` | bool | UI preference | yes |
| `animations_enabled` | bool | UI preference | yes |
| `bot_turn_delay` | number | client-side bot pacing preference | yes |
| `bot_queue_delay` | number | seconds before a Quick-queue bot fallback (clamped ≥15 server-side) | yes |
| `ranked_allow_bots` | bool | ladder bot opt-out; default `true` | **no** — `social_setting` only |
| `allow_spectators` | `"all"\|"friends"\|"off"` | spectate privacy; invalid values heal to `"all"` on load | **no** — `social_setting` only |
| `friends` | [string] | mutual, cap 100 | **no** |
| `friend_requests_in` | [string] | cap 50 | **no** |
| `friend_requests_out` | [string] | cap 50 | **no** |
| `ignored` | [string] | one-way, cap 100 | **no** |
| `match_history` | [obj] | ring buffer, newest last: `{result:"win"\|"loss", opponent, mode:<MatchType int>, my_team[], opp_team[], match_uid, date:<unix s>}`. Pruned to 7 days / 100 entries | **no** |
| `mastery_xp` | `{path: int}` | sparse per-character XP (`CharacterProgress`) | only if the key is present in the payload — the client omits it |
| `active_bounties` | `{key: int[25]}` | bingo square progress; key is `<path>` or `<path><MASTERY_SUFFIX>` | **yes** ⚠ |
| `bounty_rerolls` | `{key: int}` | reroll counter per bounty key; coerced to `{}` if not a Dictionary | **yes** ⚠ |
| `campaign_state` | object | see §7.2 | **no** — campaign intents only |
| `missions` | `{}` | vestigial; blanked on every load | n/a |
| `clan_invitations` / `clan_applications` | [string] | legacy, superseded by the clan-side lists; loaded if present, **not written by `save()`** | no |

### 7.2 `campaign_state` sub-schema

```jsonc
{
  "chapter": "chapterX",
  "node": "<node id>",
  "stage": "<stage id>",
  "flags": { "<flag>": true },
  "visited": ["<node id>"],
  "completed": ["<activation id>"],
  "pending_wins": [ { "activation": "<id>", "encounter": "<id>" } ],
  "party": ["vessel", "<path>", "<path>"],
  "vessel_loadout": ["vessel1", "vessel3"],
  "campaign_unlocked_abilities": ["<ability key>"],
  "active": { "node": "<id>", "activation": "<id>" }   // present only mid-beat; cleared on enter
}
```

`_ensure_campaign_keys` backfills `flags`, `visited`, `completed`, `pending_wins`, `vessel_loadout`.

### 7.3 `save_cosmetics.update` payload

Exactly the keys of `make_cosmetic_update()` minus the deliberately-omitted ones. The client sends:
`muted` (ignored server-side), `character_frames`, `action_frames`, `hats`, `characters`,
`mastery_profiles`, `mastery_skins`, `ingame_background`, `charselect_background`, `title`,
`unlocks`, `ap`, `clan`, `cosmetics_on`, `bot_turn_delay`, `bot_queue_delay`, `player_card`,
`avatar_url`, `bounty_rerolls`, `active_bounties`, `mark_significant`, `animations_enabled`.
Omitted on purpose: `mastery_xp`, `campaign_state`, `ranked_allow_bots`, `allow_spectators`.
⚠ **`absorb_cosmetic_update` indexes these keys with `data['key']`, not `.get()`** — a payload
missing any of them raises. The new backend should tolerate partial updates.

### 7.4 Other server-owned state (also migration surface)

| Path | Format | Contents |
|---|---|---|
| `clans/<name>.dat` | one-line JSON | `clan_name, banner_url, wins, losses, members{LEADER,OFFICER,MEMBER}, applied_players[], invited_players[]`. Created lazily (the directory is not committed) |
| `replays/<match_uid>.replay` | one-line JSON | `MatchReplayLog.to_dict()`; `match_uid` = `YYYYMMDD_<match_id>_<rand>`. Quick/Ranked/Private only — **BOT and CAMPAIGN are not persisted**. Retention: 30 days / 5000 files, swept at boot and every 24 h |
| `bucket data/…` + `poll.dat` | text | Nexus buckets + the single-int poll flag; `removed_list.dat` records permanently-removed buckets |
| `server_flags.json` | JSON | `{"creator_enabled": bool}` — the only persisted feature flag |
| `bot_tuning.json` | JSON | live bot difficulty overlay, hot-reloaded by mtime |
| mastery DB / stats DB | SQLite | `MasteryDB`, `StatsDB` (per-character picks/wins, dated appearances) |
| `stats/<char>.stats` | legacy flat files | fallback when `StatsDB` fails to open |
| `training/…` | JSON + `.replay` | bot-training status, elo ledger, team pool, replays |
| `ausers_backup_<stamp>/` | copies of `ausers/` | written automatically by a real season reset |
| `desync/` | JSON | Phase-2 desync samples (legacy; the reporting RPC is gone) |

---

## 8. Reconciliation findings

**F1 — Inbound is 1:1 apart from the Creator.** The client sends **nothing** the server does not
dispatch, and (after the Creator removal) the server dispatches 13 types the client no longer sends:
`admin_toggle_creator` and all 12 `authored_*`. Every one is Creator surface, i.e. scheduled for
deletion. Outside the Creator the correspondence is exact.

**F2 — Two non-Creator outbound frames have no client handler.** Silently dropped by `net.js`:

| Frame | Assessment |
|---|---|
| `pong` | **Intentional.** `net.js` says so explicitly — the reply exists only to keep the socket warm. Keep sending it. |
| `receive_surrender` | **Dead.** Sent to the opponent of a surrenderer, but the client has no handler; the surrender already reaches both sides through `apply_turn_result` (MATCH_ENDED). The code comments call it "a redundant ping" pending a "Phase 10" that never landed. **The new server can drop it.** |

Twelve more are now orphaned by the Creator removal: `creator_state` plus `authored_list`,
`authored_spec`, `authored_saved`, `authored_invalid`, `authored_validated`, `authored_deleted`,
`authored_reviewed`, `authored_asset_data`, `authored_upload_ready`, `authored_upload_ack`,
`authored_upload_done`. Two of those (`authored_upload_ready`, `authored_upload_ack`) were dead even
*before* the removal — the client fired `begin` → all `chunk`s → `end` without ever waiting for an
ack. None of them should be reimplemented.

**F3 — The ranked DRAFT path is entirely dead code.** `start_ranked_draft()` has **no callers**
(`_gate_tick` always calls `start_ranked_match`); its own comment says so. Therefore:
* outbound `draft_start` and `draft_update` are never emitted;
* inbound `submit_ban`, `submit_pick`, `lock_bans`, `draft_hover` can only ever answer
  `error {reason:"No active draft"}` (or no-op, for `draft_hover`);
* the client's `onDraftStart` / `onDraftUpdate` and its whole draft screen are unreachable.

Ranked uses **blind team picks**, identical to Quick. The new backend should either delete the draft
surface or implement it deliberately — but it must not be ported as "working today", because it is not.

**F4 — `receive_login_response` and `receive_player_update` ship the account's plaintext password**
back to its own client (§3.8). Strip `pass_hash` in the replacement.

**F5 — Double JSON encoding.** `receive_login_response.json_string`, `receive_player_update.json_string`,
`receive_session_reconnect.info`, and `spectate_init.info` are **JSON strings inside JSON objects**.
The client defensively handles both forms (`typeof x === "string" ? JSON.parse(x) : x`), so a new
backend may send them as nested objects without a client change. Recommended.

**F6 — Two handlers do not check authentication:** `nexus_state` and `ladder`. Both answer an
unauthenticated socket. Probably harmless (both are public leaderboards) but it should be a decision,
not an accident.

**F7 — `admin_toggle_global_chat` is not persisted** while `admin_toggle_creator` is. A restart
silently re-enables global chat. Deliberate per the comments, but worth re-confirming.

**F8 — The `receive_register_response` success test is a client-side regex** (`/success/i` on a
human-readable message). Add an explicit `ok: bool` in the new protocol and update both sides together.

**F9 — Match-start channel names are the wire contract, not the label.** A practice bot game and a
quick-queue bot fallback both arrive on `receive_quick_match`; a ranked bot game arrives on
`receive_ranked_match`. The only things distinguishing them are the `practice` and `vs_bot` booleans.
Similarly `ranked` must be tracked as a **flag**, never inferred from the display label ("Ladder
Match" does not match `/ranked/i`).

**F10 — The AP table is duplicated** in `_calculate_ap_gain` (server) and `matchApGain()` (client).
They must change together; the client's copy exists only so the game-over modal can render before
`receive_player_update` arrives.

**F11 — The client and server are now out of step on the Creator.** As of this run the client speaks
none of the 25 Creator frames while the server still serves all of them (including the *unauthenticated-
adjacent* `authored_asset_fetch`, which sits outside the kill switch). This is expected — the frontend
removal is a separate stage of the same run and the backend dies with Godot — but it means:
* the live server currently exposes 12 reachable inbound handlers with no legitimate caller;
* `_creator_blocked` (default-off flag + admin exemption) is now the *only* thing gating them;
* `_authored_team_error` still runs on every queued team, so a forged authored pick is still refused.

Nothing needs to be done about it on the Godot server. **The replacement backend must simply not
implement any of it.**

---

## 9. Acceptance checklist for the replacement backend

**Milestone 1 — non-battle core (everything marked NB above).**

- [ ] WebSocket JSON transport with a **backpressured** outbound queue; `{type, …}` envelope both ways.
- [ ] Session model: socket → session → username → (later) match. One session per account; Case A/B/C login semantics with `id` 0/1/2.
- [ ] `ping`/`pong` keepalive; `server_status` answerable **pre-auth**; `boot_id` regenerated per process.
- [ ] 120 s DISCONNECTED hold + wipe; presence fan-out to friends on every transition.
- [ ] Maintenance warn → eject (stand-down **before** the broadcast, admins excluded) → cancel.
- [ ] Account persistence with every field in §7.1, and the client-writable/server-only split preserved **exactly** (§3.4, invariant 21).
- [ ] All 5 AUTH, 4 PLAYER, 10 SOCIAL, 16 CLAN, 5 QUEUE, 1 LADDER, 2 BOUNTY, 9 CAMPAIGN, 2 NEXUS, 14 ADMIN inbound types, with the same field names.
- [ ] `_is_admin` exact-case against a small vetted list; every `admin_*` re-checks it; registration rejects case-variants.
- [ ] Every rate limit in §4 (sliding window over monotonic time, keyed by a **bounded** action name).
- [ ] Path-traversal rejection on every username/id that reaches the filesystem.
- [ ] Oracle-free social/spectate/replay denials (§3.6).
- [ ] Fix the shop (server-side purchase) and bounty progress; strip `pass_hash` from outbound frames.

**Milestone 2 — battle (built with the new Creator; everything marked B).**

- [ ] Match lifecycle, turn validation, snapshot/event stream, spectate, replay, AFK timer/forfeit.
- [ ] `session.current_match` remains the only match selector on the wire.
- [ ] Decide the fate of the dead draft surface (F3).

**Explicitly out of scope:** the entire CREATOR surface (§4.13) — being scrapped and redesigned.
